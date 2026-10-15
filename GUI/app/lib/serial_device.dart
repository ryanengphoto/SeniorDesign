import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'hub_device.dart';
import 'protocol.dart';

/// Desktop UART backend — newline-delimited JSON at 115200 8-N-1.
///
/// Prefers [flutter_libserialport] (real USB–UART). Falls back to raw
/// `dart:io` file I/O when libserialport rejects the path (common for PTY
/// peers used with `mcu_sim` — still a **dummy** peer, not the carrier PCB).
///
/// Not available on Flutter web.
class SerialDevice implements HubDevice {
  SerialDevice({
    required String portPath,
    this.baudRate = 115200,
  }) : portPath = normalizePortPath(portPath);

  final String portPath;
  final int baudRate;

  /// Windows COM10+ needs `\\.\COMn`; Linux/WSL paths pass through.
  static String normalizePortPath(String path) {
    final trimmed = path.trim();
    final match = RegExp(r'^COM(\d+)$', caseSensitive: false).firstMatch(trimmed);
    if (match == null) {
      return trimmed;
    }
    final n = int.parse(match.group(1)!);
    if (n >= 10) {
      return '\\\\.\\COM$n';
    }
    return 'COM$n';
  }

  SerialPort? _port;
  // Retained so the native reader is not GC'd while the subscription is live.
  // ignore: unused_field
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readSub;

  RandomAccessFile? _ioWrite;
  Isolate? _ioIsolate;
  ReceivePort? _ioReceive;
  StreamSubscription<dynamic>? _ioSub;

  final _framesController = StreamController<TelemetryFrame>.broadcast();
  final _statusController = StreamController<void>.broadcast();
  final StringBuffer _lineBuf = StringBuffer();

  TelemetryFrame? _latest;
  DateTime _startTime = DateTime.now();
  bool _error = false;
  String? _errorMessage;
  bool _usingIoFallback = false;

  @override
  String get mode => _error ? 'serial_error' : 'serial';

  @override
  String? get detail => portPath;

  @override
  bool get isPolled => false;

  @override
  Stream<TelemetryFrame> get frames => _framesController.stream;

  @override
  Stream<void> get statusChanges => _statusController.stream;

  @override
  int get elapsedMs => DateTime.now().difference(_startTime).inMilliseconds;

  /// Last open/read/write failure message, if any.
  String? get errorMessage => _errorMessage;

  /// True when using dart:io PTY/file transport instead of libserialport.
  bool get usingIoFallback => _usingIoFallback;

  @override
  void start() {
    _startTime = DateTime.now();
    _error = false;
    _errorMessage = null;
    _lineBuf.clear();
    _usingIoFallback = false;

    // PTY /tmp links and /dev/pts often "open" in libserialport but never
    // deliver reads (termios/get_config). Prefer dart:io for those paths.
    final preferIo = _looksLikePtyPath(portPath);
    if (preferIo) {
      if (_tryStartIoFallback()) {
        return;
      }
      if (_tryStartLibSerialPort()) {
        return;
      }
    } else {
      if (_tryStartLibSerialPort()) {
        return;
      }
      if (_tryStartIoFallback()) {
        return;
      }
    }
    _fail(
      'Failed to open $portPath via libserialport and dart:io'
      '${_errorMessage != null ? ": $_errorMessage" : ""}',
    );
  }

  static bool _looksLikePtyPath(String path) {
    if (path.startsWith('/dev/pts/')) {
      return true;
    }
    if (path.startsWith('/tmp/')) {
      return true;
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
      port?.dispose();
      _errorMessage = 'libserialport: $e';
      return false;
    }

    try {
      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      config.setFlowControl(SerialPortFlowControl.none);
      port.config = config;
      config.dispose();
    } on Object {
      // Some devices reject termios; keep the open handle.
    }

    _port = port;
    final reader = SerialPortReader(port);
    _reader = reader;
    _readSub = reader.stream.listen(
      _onBytes,
      onError: (Object e) => _fail('Serial read error: $e'),
      onDone: () => _fail('Serial port closed'),
    );
    return true;
  }

  bool _tryStartIoFallback() {
    try {
      // Write side (commands). Reader isolate opens its own read fd.
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

  @override
  void dispose() {
    _readSub?.cancel();
    _readSub = null;
    _reader = null;
    final port = _port;
    _port = null;
    if (port != null) {
      if (port.isOpen) {
        port.close();
      }
      port.dispose();
    }

    _ioSub?.cancel();
    _ioSub = null;
    _ioReceive?.close();
    _ioReceive = null;
    _ioIsolate?.kill(priority: Isolate.immediate);
    _ioIsolate = null;
    try {
      _ioWrite?.closeSync();
    } on Object {
      // ignore
    }
    _ioWrite = null;

    _framesController.close();
    _statusController.close();
  }

  @override
  TelemetryFrame? getTelemetry() => _latest;

  @override
  (PortState, int, String) isolatePort(int portId) {
    _writeCommand(CommandType.isolatePort, portId);
    return (
      PortState.manualBlocked,
      ThreatCode.manualHostKill.value,
      'Port $portId isolate command sent',
    );
  }

  @override
  (PortState, int, String) restorePort(int portId) {
    _writeCommand(CommandType.restorePort, portId);
    return (
      PortState.authorized,
      ThreatCode.noFault.value,
      'Port $portId restore command sent',
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
    if (current != null && current.threatCode == ThreatCode.noFault.value) {
      return null;
    }
    _writeCommand(CommandType.clearFault, portId);
    final previous = current != null
        ? ThreatCode.nameFor(current.threatCode)
        : 'unknown';
    return (
      current?.state ?? PortState.authorized,
      ThreatCode.noFault.value,
      'Clear fault command sent for port $portId ($previous)',
    );
  }

  void _writeCommand(CommandType cmd, int portId) {
    final line = HostCommand(cmd: cmd, port: portId).toWireLine();
    final bytes = Uint8List.fromList(utf8.encode(line));

    final port = _port;
    if (port != null && port.isOpen) {
      try {
        final written = port.write(bytes);
        if (written != bytes.length) {
          _fail('Short write on $portPath ($written/${bytes.length})');
        }
      } on Object catch (e) {
        // Common when the peer closes, USB unplugs, or usbipd detaches:
        // SerialPortError Input/output error (errno 5).
        _fail('Serial write error: $e');
      }
      return;
    }

    final io = _ioWrite;
    if (io != null) {
      try {
        io.writeFromSync(bytes);
        io.flushSync();
      } on Object catch (e) {
        _fail('IO write failed: $e');
      }
      return;
    }

    _fail('Cannot write command — port not open');
  }

  void _onBytes(Uint8List data) {
    _lineBuf.write(utf8.decode(data, allowMalformed: true));
    var content = _lineBuf.toString();
    var newline = content.indexOf('\n');
    while (newline >= 0) {
      final line = content.substring(0, newline);
      content = content.substring(newline + 1);
      final frame = TelemetryFrame.tryParseLine(line);
      if (frame != null) {
        _latest = frame;
        _error = false;
        _errorMessage = null;
        if (!_framesController.isClosed) {
          _framesController.add(frame);
        }
      }
      newline = content.indexOf('\n');
    }
    _lineBuf
      ..clear()
      ..write(content);
  }

  void _fail(String message) {
    _error = true;
    _errorMessage = message;
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
    args.sendPort.send(e.toString());
  } finally {
    try {
      raf?.closeSync();
    } on Object {
      // ignore
    }
  }
}
