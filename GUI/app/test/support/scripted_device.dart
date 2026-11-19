import 'dart:async';

import 'package:hub_console/hub_device.dart';
import 'package:hub_console/protocol.dart';

/// Controllable stream-style [HubDevice] for HubService race tests.
///
/// Not polled — call [emit] to push exact telemetry frames (stale vs current).
class ScriptedDevice implements HubDevice {
  ScriptedDevice({List<PortStatus>? initialPorts}) {
    _ports = List<PortStatus>.from(
      initialPorts ??
          [
            for (var i = 0; i < 4; i++)
              PortStatus(
                port: i,
                state: PortState.disconnected,
                threatCode: 0,
                vid: '0x0000',
                pid: '0x0000',
                devClass: '0x00',
                intClass: '0x00',
              ),
          ],
    );
  }

  late List<PortStatus> _ports;
  TelemetryFrame? _latest;
  int _elapsedMs = 0;
  String _mode = 'serial';
  String? _detail = 'COM3';
  String? _errorMessage;
  final _framesController = StreamController<TelemetryFrame>.broadcast();
  final _statusController = StreamController<void>.broadcast();

  @override
  String get mode => _mode;

  @override
  String? get detail => _detail;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get supportsReconnect => true;

  @override
  bool get supportsPortSelect => true;

  @override
  bool get supportsBaudSelect => true;

  @override
  int get baudRate => SerialBaud.defaultRate;

  @override
  bool get isPolled => false;

  @override
  int get elapsedMs => _elapsedMs;

  @override
  Stream<TelemetryFrame> get frames => _framesController.stream;

  @override
  Stream<void> get statusChanges => _statusController.stream;

  @override
  void start() {}

  @override
  void dispose() {
    _framesController.close();
    _statusController.close();
  }

  @override
  TelemetryFrame? getTelemetry() => _latest;

  @override
  void reconnect() {}

  @override
  List<String> listSerialPorts() => const ['COM3', 'COM4'];

  @override
  void setSerialPort(String portPath) {
    _detail = portPath;
    _statusController.add(null);
  }

  @override
  void setBaudRate(int baud) {}

  /// Replace one port's status (does not emit until [emit]).
  void setPort(PortStatus status) {
    _ports = [
      for (final p in _ports)
        if (p.port == status.port) status else p,
    ];
  }

  void setMode(String mode, {String? detail, String? errorMessage}) {
    _mode = mode;
    if (detail != null) {
      _detail = detail;
    }
    _errorMessage = errorMessage;
    _statusController.add(null);
  }

  /// Push the current port map as a telemetry frame.
  TelemetryFrame emit({int? timestampMs}) {
    _elapsedMs = timestampMs ?? _elapsedMs + 100;
    final frame = TelemetryFrame(
      timestampMs: _elapsedMs,
      ports: List<PortStatus>.from(_ports),
    );
    _latest = frame;
    _framesController.add(frame);
    return frame;
  }

  @override
  (PortState, int, String) isolatePort(int portId) {
    final next = _ports[portId].copyWith(
      state: PortState.manualBlocked,
      threatCode: ThreatCode.manualHostKill.value,
    );
    setPort(next);
    return (next.state, next.threatCode, 'Isolate command sent');
  }

  @override
  (PortState, int, String) restorePort(int portId) {
    final next = _ports[portId].copyWith(
      state: PortState.authorized,
      threatCode: ThreatCode.noFault.value,
    );
    setPort(next);
    return (next.state, next.threatCode, 'Restore command sent');
  }

  @override
  (PortState, int, String)? clearFault(int portId) {
    final next = _ports[portId].copyWith(
      threatCode: ThreatCode.noFault.value,
    );
    setPort(next);
    return (next.state, next.threatCode, 'Fault cleared');
  }

  @override
  (PortState, int, String)? confirmHid(int portId) {
    if (_ports[portId].state != PortState.pendingHidConfirm) {
      return null;
    }
    final next = _ports[portId].copyWith(
      state: PortState.authorized,
      threatCode: ThreatCode.noFault.value,
    );
    setPort(next);
    return (next.state, next.threatCode, 'Confirm HID command sent');
  }
}
