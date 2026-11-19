import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:meta/meta.dart';

import 'hub_device.dart';
import 'protocol.dart';

/// Desktop UART backend — newline-delimited JSON at 115200 8-N-1.
///
/// Prefers [flutter_libserialport] (real USB–UART). Falls back to raw
/// `dart:io` file I/O when libserialport rejects the path (common for PTY
/// peers used with `mcu_sim` — still a **dummy** peer, not the carrier PCB).
///
/// Link loss (unplug, peer exit, hub power loss / silent UART) sets
/// `serial_error` / `serial_reconnecting` and never throws into UI handlers.
/// Auto-reconnect with backoff; [reconnect] forces an immediate retry.
///
/// Not available on Flutter web.
class SerialDevice implements HubDevice {
  SerialDevice({
    required String portPath,
    int baudRate = 115200,
    this.telemetryTimeout = const Duration(seconds: 3),
    this.initialOpenGrace = const Duration(seconds: 5),
  })  : _portPath = normalizePortPath(portPath),
        _baudRate = baudRate > 0 ? baudRate : 115200;

  String _portPath;
  int _baudRate;

  /// Current UART path (may change via [setSerialPort] without app restart).
  String get portPath => _portPath;

  @override
  int get baudRate => _baudRate;

  /// No valid frame within this window → treat link as dead (hub silent / power).
  final Duration telemetryTimeout;

  /// After open, wait this long for the first frame before failing.
  final Duration initialOpenGrace;

  /// Windows COM10+ needs `\\.\COMn`; Linux/WSL paths pass through.
  static String normalizePortPath(String path) {
    final trimmed = path.trim();
    final prefixed =
        RegExp(r'^\\\\\.\\(COM\d+)$', caseSensitive: false).firstMatch(trimmed);
    if (prefixed != null) {
      return normalizePortPath(prefixed.group(1)!);
    }
    final match =
        RegExp(r'^COM(\d+)$', caseSensitive: false).firstMatch(trimmed);
    if (match == null) {
      return trimmed;
    }
    final n = int.parse(match.group(1)!);
    if (n >= 10) {
      return '\\\\.\\COM$n';
    }
    return 'COM$n';
  }

  /// Short label for UI (e.g. `\\.\COM10` → `COM10`).
  static String displayPortLabel(String path) {
    final normalized = normalizePortPath(path);
    final match = RegExp(r'^\\\\\.\\(COM\d+)$', caseSensitive: false)
        .firstMatch(normalized);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }
    return normalized;
  }

  SerialPort? _port;
  Timer? _pollTimer;
  final TelemetryLineBuffer _rxLines = TelemetryLineBuffer();

  RandomAccessFile? _ioWrite;
  Isolate? _ioIsolate;
  ReceivePort? _ioReceive;
  StreamSubscription<dynamic>? _ioSub;

  final _framesController = StreamController<TelemetryFrame>.broadcast();
  final _statusController = StreamController<void>.broadcast();

  TelemetryFrame? _latest;
  DateTime _startTime = DateTime.now();
  DateTime? _lastFrameAt;
  DateTime? _openedAt;

  bool _error = false;
  bool _reconnecting = false;
  bool _disposed = false;
  String? _errorMessage;
  bool _usingIoFallback = false;
  int _reconnectAttempt = 0;

  Timer? _reconnectTimer;
  Timer? _watchdog;


  @override
  String get mode {
    if (_reconnecting) {
      return 'serial_reconnecting';
    }
    if (_error) {
      return 'serial_error';
    }
    return 'serial';
  }

  @override
  String? get detail =>
      portPath.isEmpty ? null : displayPortLabel(portPath);

  @override
  String? get errorMessage => _errorMessage;

  bool get _hasPort => portPath.isNotEmpty;

  @override
  bool get supportsReconnect => true;

  @override
  bool get supportsPortSelect => true;

  @override
  bool get supportsBaudSelect => true;

  @override
  bool get isPolled => false;

  /// Enumerate host serial ports (COM / ttyUSB / …). Safe if libserialport fails.
  static List<String> enumeratePorts() {
    try {
      final ports = SerialPort.availablePorts;
      final normalized = ports
          .map(normalizePortPath)
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList(growable: false);
      normalized.sort();
      return normalized;
    } on Object {
      return const [];
    }
  }

  @override
  List<String> listSerialPorts() {
    final available = enumeratePorts();
    if (available.contains(portPath) || portPath.isEmpty) {
      return available;
    }
    // Keep the configured path visible even if temporarily missing.
    return [...available, portPath]..sort();
  }

  @override
  void setSerialPort(String nextPath) {
    if (_disposed) {
      return;
    }
    final normalized = normalizePortPath(nextPath);
    if (normalized.isEmpty) {
      return;
    }
    if (normalized == _portPath && _transportOpen && !_error) {
      return;
    }
    _portPath = normalized;
    _latest = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnecting = true;
    _error = true;
    final disp = displayPortLabel(normalized);
    _errorMessage = 'Switching to $disp…';
    _notifyStatus();
    _closeTransportOnly();
    _openTransport(resetBackoff: true);
  }

  @override
  void setBaudRate(int baud) {
    if (_disposed) {
      return;
    }
    if (baud <= 0) {
      return;
    }
    if (baud == _baudRate && _transportOpen && !_error) {
      return;
    }
    _baudRate = baud;
    if (!_hasPort) {
      _notifyStatus();
      return;
    }
    _latest = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnecting = true;
    _error = true;
    _errorMessage = 'Switching baud to $baud…';
    _notifyStatus();
    _closeTransportOnly();
    _openTransport(resetBackoff: true);
  }

  @override
  Stream<TelemetryFrame> get frames => _framesController.stream;

  @override
  Stream<void> get statusChanges => _statusController.stream;

  @override
  int get elapsedMs => DateTime.now().difference(_startTime).inMilliseconds;

  /// True when using dart:io PTY/file transport instead of libserialport.
  bool get usingIoFallback => _usingIoFallback;

  bool get _transportOpen =>
      (_port != null && (_port?.isOpen ?? false)) || _ioWrite != null;

  @override
  void start() {
    if (_disposed) {
      return;
    }
    _startTime = DateTime.now();
    _openTransport(resetBackoff: true);
  }

  @override
  void reconnect() {
    if (_disposed) {
      return;
    }
    if (!_hasPort) {
      _awaitPortSelection();
      return;
    }
    final disp = displayPortLabel(portPath);
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnecting = true;
    _error = true;
    _errorMessage = 'Reconnecting to $disp…';
    _notifyStatus();
    _closeTransportOnly();
    _openTransport(resetBackoff: true);
  }

  /// Idle until the operator picks a COM/tty in the UI.
  void _awaitPortSelection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeTransportOnly();
    _rxLines.clear();
    _usingIoFallback = false;
    _error = false;
    _reconnecting = false;
    _errorMessage = 'Select a COM port';
    _lastFrameAt = null;
    _openedAt = null;
    _latest = null;
    _notifyStatus();
  }

  void _openTransport({required bool resetBackoff}) {
    if (_disposed) {
      return;
    }
    if (!_hasPort) {
      _awaitPortSelection();
      return;
    }
    if (resetBackoff) {
      _reconnectAttempt = 0;
    }

    _closeTransportOnly();
    _rxLines.clear();
    _usingIoFallback = false;
    _error = false;
    _reconnecting = false;
    _errorMessage = null;
    _lastFrameAt = null;
    _openedAt = DateTime.now();

    final preferIo = _looksLikePtyPath(portPath);
    var opened = false;
    if (preferIo) {
      opened = _tryStartIoFallback() || _tryStartLibSerialPort();
    } else {
      opened = _tryStartLibSerialPort() ||
          (!_isWindowsComPort(portPath) && _tryStartIoFallback());
    }

    if (!opened) {
      final disp = displayPortLabel(portPath);
      _fail(
        '$disp disconnected',
        scheduleReconnect: true,
      );
      return;
    }

    _startWatchdog();
    _notifyStatus();
  }

  static bool _isWindowsComPort(String path) =>
      RegExp(r'^(\\\\\.\\)?COM\d+$', caseSensitive: false).hasMatch(path);

  static bool _looksLikePtyPath(String path) {
    if (path.startsWith('/dev/pts/')) {
      return true;
    }
    if (path.startsWith('/tmp/')) {
      return true;
    }
    // Windows COM ports are never PTY.
    if (_isWindowsComPort(path)) {
      return false;
    }
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      return type == FileSystemEntityType.link;
    } on Object {
      return false;
    }
  }

  bool _tryStartLibSerialPort() {
    SerialPort? port;
    try {
      port = SerialPort(portPath);
      if (!port.openReadWrite()) {
        final err = SerialPort.lastError;
        port.dispose();
        _errorMessage = 'libserialport: $err';
        return false;
      }
    } on Object catch (e) {
      try {
        port?.dispose();
      } on Object {
        // ignore
      }
      _errorMessage = 'libserialport: $e';
      return false;
    }

    SerialPortConfig? config;
    try {
      config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      config.setFlowControl(SerialPortFlowControl.none);
      port.config = config;
      // Do not dispose config here: SerialPort retains config in its internal
      // _config field and automatically calls _config.dispose() during
      // port.dispose(). Calling dispose here causes a native CRT double-free
      // assert (is_block_type_valid) upon port cleanup/reconnect.
    } on Object {
      // Only dispose if assigning to port.config failed and port did not take ownership.
      try {
        config?.dispose();
      } on Object {
        // ignore
      }
    }

    _port = port;
    _startPortPolling(port);
    return true;
  }

  void _startPortPolling(SerialPort port) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (_disposed || _error || !_transportOpen) {
        return;
      }
      try {
        final available = port.bytesAvailable;
        if (available > 0) {
          final data = port.read(available);
          if (data.isNotEmpty) {
            _onBytes(data);
          }
        } else if (available < 0) {
          final err = SerialPort.lastError;
          _fail('Serial port error: $err');
        }
      } on Object catch (e) {
        _fail('Serial read error: $e');
      }
    });
  }

  bool _tryStartIoFallback() {
    try {
      _ioWrite = File(portPath).openSync(mode: FileMode.writeOnly);
      _ioReceive = ReceivePort();
      _ioSub = _ioReceive!.listen((message) {
        if (message is Uint8List) {
          _onBytes(message);
        } else if (message is String) {
          _fail('IO serial reader: $message');
        }
      });
      Isolate.spawn(
        _ioReadIsolateMain,
        _IoReadSpawn(portPath, _ioReceive!.sendPort),
      ).then((iso) {
        if (_disposed || _ioReceive == null) {
          iso.kill(priority: Isolate.immediate);
          return;
        }
        _ioIsolate = iso;
      }).catchError((Object e) {
        _fail('IO isolate spawn failed: $e');
      });
      _usingIoFallback = true;
      return true;
    } on Object catch (e) {
      _errorMessage = 'dart:io: $e';
      try {
        _ioWrite?.closeSync();
      } on Object {
        // ignore
      }
      _ioWrite = null;
      _ioReceive?.close();
      _ioReceive = null;
      return false;
    }
  }

  void _closeTransportOnly() {
    _watchdog?.cancel();
    _watchdog = null;

    _pollTimer?.cancel();
    _pollTimer = null;

    final port = _port;
    _port = null;
    if (port != null) {
      try {
        if (port.isOpen) {
          port.close();
        }
      } on Object {
        // ignore — already torn down after unplug
      }
      try {
        port.dispose();
      } on Object {
        // ignore
      }
    }

    try {
      _ioSub?.cancel();
    } on Object {
      // ignore
    }
    _ioSub = null;
    try {
      _ioReceive?.close();
    } on Object {
      // ignore
    }
    _ioReceive = null;
    try {
      _ioIsolate?.kill(priority: Isolate.immediate);
    } on Object {
      // ignore
    }
    _ioIsolate = null;
    try {
      _ioWrite?.closeSync();
    } on Object {
      // ignore
    }
    _ioWrite = null;
    _usingIoFallback = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeTransportOnly();
    if (!_framesController.isClosed) {
      _framesController.close();
    }
    if (!_statusController.isClosed) {
      _statusController.close();
    }
  }

  @override
  TelemetryFrame? getTelemetry() => _latest;

  @override
  (PortState, int, String) isolatePort(int portId) {
    if (!_writeCommand(CommandType.isolatePort, portId)) {
      return (
        PortState.manualBlocked,
        ThreatCode.manualHostKill.value,
        'Isolate not sent, link down',
      );
    }
    return (
      PortState.manualBlocked,
      ThreatCode.manualHostKill.value,
      'Isolate command sent',
    );
  }

  @override
  (PortState, int, String) restorePort(int portId) {
    if (!_writeCommand(CommandType.restorePort, portId)) {
      return (
        PortState.authorized,
        ThreatCode.noFault.value,
        'Restore not sent, link down',
      );
    }
    return (
      PortState.authorized,
      ThreatCode.noFault.value,
      'Restore command sent',
    );
  }

  @override
  (PortState, int, String)? clearFault(int portId) {
    PortStatus? current;
    final ports = _latest?.ports;
    if (ports != null) {
      for (final p in ports) {
        if (p.port == portId) {
          current = p;
          break;
        }
      }
    }
    if (current != null && current.state == PortState.pendingHidConfirm) {
      return (
        current.state,
        current.threatCode,
        'Clear fault ignored, use Confirm keyboard',
      );
    }
    if (current != null && current.threatCode == ThreatCode.noFault.value) {
      return null;
    }
    final previous = current != null
        ? ThreatCode.nameFor(current.threatCode)
        : 'unknown';
    if (!_writeCommand(CommandType.clearFault, portId)) {
      return (
        current?.state ?? PortState.authorized,
        ThreatCode.noFault.value,
        'Clear fault not sent, link down',
      );
    }
    return (
      current?.state ?? PortState.authorized,
      ThreatCode.noFault.value,
      'Clear fault command sent ($previous)',
    );
  }

  @override
  (PortState, int, String)? confirmHid(int portId) {
    PortStatus? current;
    final ports = _latest?.ports;
    if (ports != null) {
      for (final p in ports) {
        if (p.port == portId) {
          current = p;
          break;
        }
      }
    }
    if (current != null && current.state != PortState.pendingHidConfirm) {
      return null;
    }
    if (!_writeCommand(CommandType.confirmHid, portId)) {
      return (
        current?.state ?? PortState.pendingHidConfirm,
        ThreatCode.noFault.value,
        'Confirm HID not sent, link down',
      );
    }
    return (
      PortState.authorized,
      ThreatCode.noFault.value,
      'Confirm HID command sent',
    );
  }

  /// Returns false if the link is down or the write failed (never throws).
  bool _writeCommand(CommandType cmd, int portId) {
    if (_disposed || _error || !_transportOpen) {
      return false;
    }

    final line = HostCommand(cmd: cmd, port: portId).toWireLine();
    final bytes = Uint8List.fromList(utf8.encode(line));

    final port = _port;
    if (port != null && port.isOpen) {
      try {
        final written = port.write(bytes);
        if (written != bytes.length) {
          _fail('Short write on $portPath ($written/${bytes.length})');
          return false;
        }
        return true;
      } on Object catch (e) {
        _fail('Serial write error: $e');
        return false;
      }
    }

    final io = _ioWrite;
    if (io != null) {
      try {
        io.writeFromSync(bytes);
        io.flushSync();
        return true;
      } on Object catch (e) {
        _fail('IO write failed: $e');
        return false;
      }
    }

    _fail('Cannot write command, port not open');
    return false;
  }

  void _onBytes(Uint8List data) {
    if (_disposed || _error) {
      // Drop late bytes from a dying reader after we already failed.
      return;
    }
    try {
      for (final frame in _rxLines.push(data)) {
        _latest = frame;
        _lastFrameAt = DateTime.now();
        _error = false;
        _reconnecting = false;
        _errorMessage = null;
        _reconnectAttempt = 0;
        if (!_framesController.isClosed) {
          _framesController.add(frame);
        }
      }
    } on Object catch (e) {
      // TelemetryLineBuffer already swallows parse errors; this is belt-and-suspenders.
      _fail('Serial decode error: $e');
    }
  }

  /// Test-only: feed RX bytes as if they arrived on the UART.
  /// Bypasses link-up / error gates so garbage and good frames can be exercised
  /// without opening a real COM port.
  @visibleForTesting
  void injectRxForTest(List<int> data) {
    for (final frame in _rxLines.push(data)) {
      _latest = frame;
      _lastFrameAt = DateTime.now();
      _error = false;
      _reconnecting = false;
      _errorMessage = null;
      if (!_framesController.isClosed) {
        _framesController.add(frame);
      }
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || _error || !_transportOpen) {
        return;
      }
      final now = DateTime.now();
      final disp = displayPortLabel(portPath);
      if (_lastFrameAt != null) {
        if (now.difference(_lastFrameAt!) > telemetryTimeout) {
          _fail(
            '$disp silent for ${telemetryTimeout.inSeconds}s (peer silent or hub power loss)',
          );
        }
        return;
      }
      final opened = _openedAt;
      if (opened != null && now.difference(opened) > initialOpenGrace) {
        _fail(
          'No telemetry on $disp within ${initialOpenGrace.inSeconds}s of open',
        );
      }
    });
  }

  void _fail(String message, {bool scheduleReconnect = true}) {
    if (_disposed) {
      return;
    }

    final alreadyDown = _error && !_transportOpen;
    _error = true;
    _errorMessage = message;
    // Drop last frame so the UI cannot show AUTHORIZED/PENDING while COM is dead.
    _latest = null;
    _lastFrameAt = null;
    if (!alreadyDown) {
      _closeTransportOnly();
    }

    // Only allow one automatic reconnect attempt before stopping and waiting for user.
    if (!scheduleReconnect || _reconnectAttempt >= 1) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnecting = false;
      _notifyStatus();
      return;
    }

    // Keep an in-flight backoff timer; only start one if idle.
    if (_reconnectTimer != null) {
      _reconnecting = true;
      _notifyStatus();
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) {
      return;
    }
    if (!_hasPort) {
      _awaitPortSelection();
      return;
    }
    _reconnectTimer?.cancel();
    _reconnecting = true;
    _reconnectAttempt += 1;

    final disp = displayPortLabel(portPath);
    _errorMessage = '$disp disconnected — retrying…';
    _notifyStatus();

    _reconnectTimer = Timer(const Duration(seconds: 1), () {
      _reconnectTimer = null;
      if (_disposed) {
        return;
      }
      _reconnecting = true;
      _errorMessage = 'Reconnecting to $disp…';
      _notifyStatus();
      _openTransport(resetBackoff: false);
    });
  }

  void _notifyStatus() {
    if (!_statusController.isClosed) {
      _statusController.add(null);
    }
  }
}

class _IoReadSpawn {
  const _IoReadSpawn(this.path, this.sendPort);
  final String path;
  final SendPort sendPort;
}

/// Blocking reader isolate for PTY / raw tty paths libserialport rejects.
void _ioReadIsolateMain(_IoReadSpawn args) {
  RandomAccessFile? raf;
  try {
    raf = File(args.path).openSync(mode: FileMode.read);
    final buffer = Uint8List(512);
    while (true) {
      final n = raf.readIntoSync(buffer);
      if (n <= 0) {
        sleep(const Duration(milliseconds: 10));
        continue;
      }
      args.sendPort.send(Uint8List.fromList(buffer.sublist(0, n)));
    }
  } on Object catch (e) {
    try {
      args.sendPort.send(e.toString());
    } on Object {
      // isolate / port already closed
    }
  } finally {
    try {
      raf?.closeSync();
    } on Object {
      // ignore
    }
  }
}
