import 'dart:async';
import 'dart:math';

import 'hub_device.dart';
import 'protocol.dart';

/// In-memory hub simulator — not real hardware.
///
/// Demo script:
/// - Port 0 starts as an authorized flash drive
/// - Port 1: enumerate (~5s) → keyboard (~8s) → KEYSTROKE_BURST (~15s)
class MockDevice implements HubDevice {
  MockDevice() {
    _ports = [
      _Port(
        port: 0,
        state: PortState.authorized,
        vbusMv: 5020,
        currentMa: 42,
        vid: '0x0781',
        pid: '0x5583',
        devClass: '0x00',
        intClass: '0x08',
      ),
      _Port(port: 1),
      _Port(port: 2),
      _Port(port: 3),
    ];
  }

  late final List<_Port> _ports;
  final _rng = Random();
  DateTime _startTime = DateTime.now();
  int _scriptStage = 0;
  final _framesController = StreamController<TelemetryFrame>.broadcast();

  @override
  String get mode => 'mock';

  @override
  String? get detail => null;

  @override
  String? get errorMessage => null;

  @override
  bool get supportsReconnect => false;

  @override
  void reconnect() {}

  @override
  bool get isPolled => true;

  @override
  Stream<TelemetryFrame> get frames => _framesController.stream;

  @override
  Stream<void> get statusChanges => Stream<void>.empty();

  @override
  void start() {
    _startTime = DateTime.now();
    _scriptStage = 0;
  }

  @override
  void dispose() {
    _framesController.close();
  }

  @override
  int get elapsedMs => DateTime.now().difference(_startTime).inMilliseconds;

  @override
  TelemetryFrame getTelemetry() {
    _advanceScript();
    _jitterReadings();
    return TelemetryFrame(
      timestampMs: elapsedMs,
      ports: _ports.map(_toStatus).toList(growable: false),
    );
  }

  @override
  (PortState, int, String) isolatePort(int portId) {
    final port = _ports[portId];
    port.manuallyBlocked = true;
    port.state = PortState.manualBlocked;
    port.threatCode = ThreatCode.manualHostKill.value;
    port.vbusMv = 0;
    port.currentMa = 0;
    return (
      port.state,
      port.threatCode,
      'Port $portId manually isolated by operator',
    );
  }

  @override
  (PortState, int, String) restorePort(int portId) {
    final port = _ports[portId];
    port.manuallyBlocked = false;
    port.threatCode = ThreatCode.noFault.value;
    port.state = PortState.authorized;
    port.vbusMv = 5020;
    port.currentMa = 30 + _rng.nextInt(51);
    port.vid = '0x046D';
    port.pid = '0xC31C';
    port.devClass = '0x00';
    port.intClass = '0x03';
    return (
      port.state,
      port.threatCode,
      'Port $portId restored and authorized',
    );
  }

  @override
  (PortState, int, String)? clearFault(int portId) {
    final port = _ports[portId];
    if (port.threatCode == ThreatCode.noFault.value) {
      return null;
    }

    final previous = ThreatCode.nameFor(port.threatCode);
    port.threatCode = ThreatCode.noFault.value;

    if (port.manuallyBlocked) {
      port.state = PortState.manualBlocked;
      return (
        port.state,
        port.threatCode,
        'Fault cleared on port $portId ($previous); port remains isolated',
      );
    }

    port.state = PortState.authorized;
    port.vbusMv = 5020;
    port.currentMa = 20 + _rng.nextInt(41);
    return (
      port.state,
      port.threatCode,
      'Fault cleared on port $portId ($previous)',
    );
  }

  PortStatus _toStatus(_Port port) {
    return PortStatus(
      port: port.port,
      state: port.state,
      threatCode: port.threatCode,
      vbusMv: port.vbusMv,
      currentMa: port.currentMa,
      vid: port.vid,
      pid: port.pid,
      devClass: port.devClass,
      intClass: port.intClass,
    );
  }

  void _jitterReadings() {
    for (final port in _ports) {
      if (port.vbusMv > 0 &&
          (port.state == PortState.authorized ||
              port.state == PortState.enumerating)) {
        port.currentMa = max(0, port.currentMa + _rng.nextInt(7) - 3);
      }
    }
  }

  void _advanceScript() {
    final elapsedS = DateTime.now().difference(_startTime).inMilliseconds / 1000.0;
    final port1 = _ports[1];

    if (port1.manuallyBlocked || port1.state == PortState.quarantined) {
      return;
    }

    if (_scriptStage == 0 && elapsedS >= 5) {
      port1.state = PortState.enumerating;
      port1.vbusMv = 5020;
      port1.currentMa = 15;
      _scriptStage = 1;
      return;
    }

    if (_scriptStage == 1 && elapsedS >= 8) {
      port1.state = PortState.authorized;
      port1.vid = '0x046D';
      port1.pid = '0xC31C';
      port1.devClass = '0x00';
      port1.intClass = '0x03';
      port1.currentMa = 55;
      _scriptStage = 2;
      return;
    }

    if (_scriptStage == 2 && elapsedS >= 15) {
      port1.state = PortState.quarantined;
      port1.threatCode = ThreatCode.keystrokeBurst.value;
      port1.vbusMv = 0;
      port1.currentMa = 0;
      _scriptStage = 3;
    }
  }
}

class _Port {
  _Port({
    required this.port,
    this.state = PortState.disconnected,
    this.vbusMv = 0,
    this.currentMa = 0,
    this.vid = '0x0000',
    this.pid = '0x0000',
    this.devClass = '0x00',
    this.intClass = '0x00',
  });

  final int port;
  PortState state;
  int threatCode = 0;
  int vbusMv;
  int currentMa;
  String vid;
  String pid;
  String devClass;
  String intClass;
  bool manuallyBlocked = false;
}
