import 'dart:async';
import 'dart:collection';

import 'db/event_log_store.dart';
import 'device_factory.dart';
import 'hub_device.dart';
import 'mock_device.dart';
import 'protocol.dart';

/// Orchestrates hub telemetry + command handling.
///
/// Default is in-process [MockDevice]. Pass a [HubDevice] or use
/// [HubService.fromEnvironment] for `--dart-define=HUB_MODE=serial`.
///
/// Security events are persisted via [EventLogStore] (Drift) and reloaded
/// on [start] (last [maxEvents]).
class HubService {
  HubService({
    HubDevice? device,
    EventLogStore? eventLog,
    this.maxEvents = 200,
  })  : _device = device ?? MockDevice(),
        _eventLog = eventLog ?? EventLogStore(),
        _ownsEventLog = eventLog == null;

  factory HubService.fromEnvironment({int maxEvents = 200}) {
    return HubService(
      device: createHubDeviceFromEnvironment(),
      maxEvents: maxEvents,
    );
  }

  final int maxEvents;
  final HubDevice _device;
  final EventLogStore _eventLog;
  final bool _ownsEventLog;
  final ListQueue<SecurityEvent> _events = ListQueue();
  final Map<int, (PortState, int)> _lastSnapshot = {};

  /// After confirm_hid, ignore late PENDING (not the real attach→pending wait).
  final Set<int> _stalePendingAfterConfirm = {};

  /// After isolate_port, ignore late AUTHORIZED until restore (or real unblock).
  final Set<int> _staleAuthorizedAfterIsolate = {};

  final _telemetryController = StreamController<TelemetryFrame>.broadcast();
  final _eventsController = StreamController<List<SecurityEvent>>.broadcast();

  Timer? _tick;
  StreamSubscription<TelemetryFrame>? _frameSub;
  StreamSubscription<void>? _statusSub;
  bool _started = false;
  String _lastMode = '';

  String get mode => _device.mode;

  /// Serial port path when connected via UART; null for mock.
  String? get detail => _device.detail;

  /// Last serial transport error (null for mock / healthy link).
  String? get errorMessage => _device.errorMessage;

  bool get supportsReconnect => _device.supportsReconnect;

  bool get supportsPortSelect => _device.supportsPortSelect;

  bool get supportsBaudSelect => _device.supportsBaudSelect;

  int get baudRate => _device.baudRate;

  Stream<TelemetryFrame> get telemetryStream => _telemetryController.stream;
  Stream<List<SecurityEvent>> get eventsStream => _eventsController.stream;

  List<SecurityEvent> get events => _events.toList(growable: false);

  TelemetryFrame? latestTelemetry;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    await _eventLog.open();
    final prior = await _eventLog.loadRecent(maxEvents);
    _events.clear();
    // Skip legacy UART/COM/baud host-link rows — not security events.
    for (final event in prior) {
      if (event.isSystem) {
        if (event.id != null) {
          unawaited(_eventLog.deleteById(event.id!));
        }
        continue;
      }
      _events.addLast(event);
    }
    _emitEvents();

    // Subscribe before start so broadcast UART frames are not dropped.
    _lastMode = _device.mode;
    _statusSub = _device.statusChanges.listen((_) => _onDeviceStatus());
    if (!_device.isPolled) {
      _frameSub = _device.frames.listen(_onSerialFrame);
    }

    _device.start();
    _onDeviceStatus();

    if (_device.isPolled) {
      _recordInitialFrom(_device.getTelemetry());
      _publishFrame(_device.getTelemetry());
      _tick = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _publishFrame(_device.getTelemetry()),
      );
    } else {
      final existing = _device.getTelemetry();
      if (existing != null) {
        _recordInitialFrom(existing);
        _publishFrame(existing);
      } else {
        _emitStatusOnly();
      }
    }
  }

  void dispose() {
    _tick?.cancel();
    _tick = null;
    unawaited(_frameSub?.cancel() ?? Future<void>.value());
    _frameSub = null;
    unawaited(_statusSub?.cancel() ?? Future<void>.value());
    _statusSub = null;
    _device.dispose();
    if (_ownsEventLog) {
      unawaited(_eventLog.close());
    }
    if (!_telemetryController.isClosed) {
      unawaited(_telemetryController.close());
    }
    if (!_eventsController.isClosed) {
      unawaited(_eventsController.close());
    }
  }

  void _emitStatusOnly() {
    _emitEvents();
  }

  void _emitEvents() {
    if (!_eventsController.isClosed) {
      _eventsController.add(events);
    }
  }

  /// Force serial reopen (no-op for mock). Safe to call from UI.
  void reconnect() {
    if (!_device.supportsReconnect) {
      return;
    }
    try {
      _device.reconnect();
    } on Object {
      // Header banner shows link errors; do not log host/UART status.
    }
    _onDeviceStatus();
  }

  /// Host COM / tty paths for the serial picker (empty in mock).
  List<String> listSerialPorts() => _device.listSerialPorts();

  /// Switch UART device without restarting the app (serial only).
  void setSerialPort(String portPath) {
    if (!_device.supportsPortSelect) {
      return;
    }
    try {
      _device.setSerialPort(portPath);
      latestTelemetry = null;
    } on Object {
      // Header banner shows link errors; do not log host/UART status.
    }
    _onDeviceStatus();
  }

  /// Change UART baud without restarting the app (serial only).
  void setBaudRate(int baud) {
    if (!_device.supportsBaudSelect) {
      return;
    }
    if (baud == _device.baudRate) {
      return;
    }
    try {
      _device.setBaudRate(baud);
      latestTelemetry = null;
    } on Object {
      // Header banner shows link errors; do not log host/UART status.
    }
    _onDeviceStatus();
  }

  void _onDeviceStatus() {
    final next = _device.mode;
    if (next != _lastMode) {
      _lastMode = next;
    }
    // Serial link lost: clear frozen port cards (last JSON before CP2102 went quiet).
    final lower = next.toLowerCase();
    if (lower.contains('error') || lower.contains('reconnect')) {
      if (latestTelemetry != null) {
        latestTelemetry = null;
        _lastSnapshot.clear();
        if (!_telemetryController.isClosed) {
          _telemetryController.add(
            TelemetryFrame(
              timestampMs: DateTime.now().millisecondsSinceEpoch,
              ports: const [],
            ),
          );
        }
      }
    }
    _emitStatusOnly();
  }

  SecurityEvent? handleCommand(CommandType cmd, int port) {
    (PortState, int, String)? result;
    try {
      result = switch (cmd) {
        CommandType.isolatePort => _device.isolatePort(port),
        CommandType.restorePort => _device.restorePort(port),
        CommandType.clearFault => _device.clearFault(port),
        CommandType.confirmHid => _device.confirmHid(port),
      };
    } on Object catch (e) {
      result = (
        PortState.disconnected,
        ThreatCode.manualHostKill.value,
        'Command failed (link error): $e',
      );
    }

    if (result == null) {
      return null;
    }

    final (state, threatCode, message) = result;
    final event = SecurityEvent(
      at: DateTime.now(),
      port: port,
      threatCode: threatCode,
      threatName: ThreatCode.nameFor(threatCode),
      state: state,
      message: message,
    );
    unawaited(_appendEvent(event));

    // Log the operator command immediately; leave snapshot on the prior
    // hardware state so the next telemetry frame can log "Changed to …".
    switch (cmd) {
      case CommandType.confirmHid:
        _stalePendingAfterConfirm.add(port);
      case CommandType.isolatePort:
        _staleAuthorizedAfterIsolate.add(port);
        // Isolate ends any prior HID-confirm session; don't suppress the next PENDING.
        _stalePendingAfterConfirm.remove(port);
      case CommandType.restorePort:
        _staleAuthorizedAfterIsolate.remove(port);
        _stalePendingAfterConfirm.remove(port);
      case CommandType.clearFault:
        _lastSnapshot[port] = (state, threatCode);
    }

    if (_device.isPolled) {
      _publishFrame(_device.getTelemetry());
    } else {
      _emitEvents();
    }
    return event;
  }

  void _onSerialFrame(TelemetryFrame frame) {
    try {
      if (_lastSnapshot.isEmpty) {
        _recordInitialFrom(frame);
      }
      // Frames clear device error flags; sync mode for the banner.
      if (_lastMode != _device.mode) {
        _onDeviceStatus();
      }
      _publishFrame(frame);
    } on Object {
      // Never let a bad frame tear down the console UI.
    }
  }

  void _publishFrame(TelemetryFrame? telemetry) {
    if (telemetry == null) {
      return;
    }
    try {
      _detectChanges(telemetry);
      latestTelemetry = telemetry;
      if (!_telemetryController.isClosed) {
        _telemetryController.add(telemetry);
      }
      _emitEvents();
    } on Object {
      // Keep last good telemetry; skip this frame's side effects.
    }
  }

  void _recordInitialFrom(TelemetryFrame? telemetry) {
    if (telemetry == null) {
      return;
    }
    for (final port in telemetry.ports) {
      _lastSnapshot[port.port] = (port.state, port.threatCode);
    }
  }

  void _detectChanges(TelemetryFrame telemetry) {
    for (final port in telemetry.ports) {
      final previous = _lastSnapshot[port.port];
      final current = (port.state, port.threatCode);
      if (previous == current) {
        continue;
      }

      if (previous == null) {
        _lastSnapshot[port.port] = current;
        continue;
      }

      final (prevState, _) = previous;

      // Stale in-flight frames after operator commands — keep snapshot, no log.
      if (port.state == PortState.pendingHidConfirm &&
          prevState == PortState.authorized &&
          _stalePendingAfterConfirm.contains(port.port)) {
        continue;
      }
      if (port.state == PortState.authorized &&
          prevState == PortState.manualBlocked &&
          _staleAuthorizedAfterIsolate.contains(port.port)) {
        continue;
      }

      _lastSnapshot[port.port] = current;
      if (port.threatCode == 0 && port.state == prevState) {
        continue;
      }

      if (port.state == PortState.authorized) {
        _stalePendingAfterConfirm.remove(port.port);
      }
      if (port.state == PortState.disconnected) {
        _stalePendingAfterConfirm.remove(port.port);
        _staleAuthorizedAfterIsolate.remove(port.port);
      }

      final threat = ThreatCode.fromValue(port.threatCode);
      // Port identity lives in the event card label — keep messages port-free.
      final String message;
      if (threat == ThreatCode.keystrokeBurst &&
          port.state == PortState.quarantined) {
        message = '${threat.summary} — quarantined';
      } else if (threat == ThreatCode.unauthorizedHid) {
        message =
            'Unauthorized ${UsbClass.display(port.intClass)} on storage-only port';
      } else if (port.state == PortState.pendingHidConfirm) {
        message = 'HID device waiting for operator confirm';
      } else if (port.state == PortState.authorized &&
          prevState == PortState.disconnected) {
        // Attached / enumerated — not the same as operator HID confirm.
        message = 'Device attached';
      } else if (port.threatCode > 0 &&
          threat != ThreatCode.manualHostKill) {
        // Summary only — no fabric detail subtitle in the sidebar.
        message = threat.summary;
      } else {
        // Includes MANUAL_BLOCKED / AUTHORIZED after confirm or restore.
        message = 'Changed to ${port.state.wireName}';
      }

      unawaited(
        _appendEvent(
          SecurityEvent(
            at: DateTime.now(),
            port: port.port,
            threatCode: port.threatCode,
            threatName: ThreatCode.nameFor(port.threatCode),
            state: port.state,
            message: message,
          ),
        ),
      );
    }
  }

  Future<void> clearAllEvents() async {
    _events.clear();
    _emitEvents();
    try {
      await _eventLog.clearAll();
    } on Object {
      // UI already cleared; ignore disk failures.
    }
  }

  Future<void> deleteEvent(int id) async {
    _events.removeWhere((e) => e.id == id);
    _emitEvents();
    try {
      await _eventLog.deleteById(id);
    } on Object {
      // UI already updated; ignore disk failures.
    }
  }

  Future<void> _appendEvent(SecurityEvent event) async {
    // Host/UART link status belongs in the header banner, not the security log.
    if (event.isSystem) {
      return;
    }
    _events.addLast(event);
    while (_events.length > maxEvents) {
      _events.removeFirst();
    }
    _emitEvents();
    try {
      final id = await _eventLog.append(event);
      final updated = <SecurityEvent>[];
      var replaced = false;
      for (final e in _events) {
        if (!replaced &&
            e.id == null &&
            e.at == event.at &&
            e.port == event.port &&
            e.message == event.message) {
          updated.add(event.copyWith(id: id));
          replaced = true;
        } else {
          updated.add(e);
        }
      }
      _events
        ..clear()
        ..addAll(updated);
      _emitEvents();
      await _eventLog.trimTo(maxEvents);
    } on Object {
      // Keep UI ring even if disk write fails.
    }
  }
}
