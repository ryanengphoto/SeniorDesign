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

  final _telemetryController = StreamController<TelemetryFrame>.broadcast();
  final _eventsController = StreamController<List<SecurityEvent>>.broadcast();

  Timer? _tick;
  StreamSubscription<TelemetryFrame>? _frameSub;
  StreamSubscription<void>? _statusSub;
  bool _started = false;

  String get mode => _device.mode;

  /// Serial port path when connected via UART; null for mock.
  String? get detail => _device.detail;

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
    for (final event in prior) {
      _events.addLast(event);
    }
    _emitEvents();

    // Subscribe before start so broadcast UART frames are not dropped.
    _statusSub = _device.statusChanges.listen((_) => _emitStatusOnly());
    if (!_device.isPolled) {
      _frameSub = _device.frames.listen(_onSerialFrame);
    }

    _device.start();

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

  SecurityEvent? handleCommand(CommandType cmd, int port) {
    final (PortState, int, String)? result = switch (cmd) {
      CommandType.isolatePort => _device.isolatePort(port),
      CommandType.restorePort => _device.restorePort(port),
      CommandType.clearFault => _device.clearFault(port),
    };

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
    _lastSnapshot[port] = (state, threatCode);
    if (_device.isPolled) {
      _publishFrame(_device.getTelemetry());
    } else {
      _emitEvents();
    }
    return event;
  }

  void _onSerialFrame(TelemetryFrame frame) {
    if (_lastSnapshot.isEmpty) {
      _recordInitialFrom(frame);
    }
    _publishFrame(frame);
  }

  void _publishFrame(TelemetryFrame? telemetry) {
    if (telemetry == null) {
      return;
    }
    _detectChanges(telemetry);
    latestTelemetry = telemetry;
    if (!_telemetryController.isClosed) {
      _telemetryController.add(telemetry);
    }
    _emitEvents();
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

      _lastSnapshot[port.port] = current;
      if (previous == null) {
        continue;
      }

      final (prevState, _) = previous;
      if (port.threatCode == 0 && port.state == prevState) {
        continue;
      }

      final String message;
      if (port.threatCode == 2 && port.state == PortState.quarantined) {
        message = 'Keystroke burst detected on port ${port.port}';
      } else if (port.threatCode == 1) {
        message = 'Unauthorized HID detected on port ${port.port}';
      } else if (port.state == PortState.enumerating) {
        message = 'Device enumerating on port ${port.port}';
      } else if (port.state == PortState.authorized &&
          prevState == PortState.enumerating) {
        message = 'Device authorized on port ${port.port}';
      } else {
        message =
            'Port ${port.port} changed to ${port.state.wireName} (${ThreatCode.nameFor(port.threatCode)})';
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

  Future<void> _appendEvent(SecurityEvent event) async {
    _events.addLast(event);
    while (_events.length > maxEvents) {
      _events.removeFirst();
    }
    _emitEvents();
    try {
      await _eventLog.append(event);
      await _eventLog.trimTo(maxEvents);
    } on Object {
      // Keep UI ring even if disk write fails.
    }
  }
}
