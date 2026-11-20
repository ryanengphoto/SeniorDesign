/// Host ↔ hub protocol models.
///
/// Keep aligned with `Docs/firmwmare_slop.md` and `Docs/fabric_slop.md`.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Lenient JSON helpers — UART peers may emit ints as doubles/strings.
int? _jsonInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

String _jsonString(Object? value, [String fallback = '']) {
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

Map<String, dynamic>? _jsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

enum PortState {
  disconnected,
  authorized,
  quarantined,
  manualBlocked,
  pendingHidConfirm;

  String get wireName => switch (this) {
        PortState.disconnected => 'DISCONNECTED',
        PortState.authorized => 'AUTHORIZED',
        PortState.quarantined => 'QUARANTINED',
        PortState.manualBlocked => 'MANUAL_BLOCKED',
        PortState.pendingHidConfirm => 'PENDING_HID_CONFIRM',
      };

  String get label => wireName.replaceAll('_', ' ');

  static PortState fromWireName(String name) {
    for (final state in PortState.values) {
      if (state.wireName == name) {
        return state;
      }
    }
    return PortState.disconnected;
  }
}

enum ThreatCode {
  noFault(0),
  unauthorizedHid(1),
  keystrokeBurst(2),
  cooldownBurst(3),
  descriptorOverflow(4),
  crcTokenFault(5),
  bitStuffError(6),
  manualHostKill(7);

  const ThreatCode(this.value);
  final int value;

  /// Wire / log identifier (fabric §6).
  String get name => switch (this) {
        ThreatCode.noFault => 'NO_FAULT',
        ThreatCode.unauthorizedHid => 'UNAUTHORIZED_HID',
        ThreatCode.keystrokeBurst => 'KEYSTROKE_BURST',
        ThreatCode.cooldownBurst => 'COOLDOWN_BURST',
        ThreatCode.descriptorOverflow => 'DESCRIPTOR_OVERFLOW',
        ThreatCode.crcTokenFault => 'CRC_TOKEN_FAULT',
        ThreatCode.bitStuffError => 'BIT_STUFF_ERROR',
        ThreatCode.manualHostKill => 'MANUAL_HOST_KILL',
      };

  /// Short operator-facing title.
  String get summary => switch (this) {
        ThreatCode.noFault => 'No fault',
        ThreatCode.unauthorizedHid => 'Unauthorized HID',
        ThreatCode.keystrokeBurst => 'Keystroke burst',
        ThreatCode.cooldownBurst => 'Cooldownoldown burst',
        ThreatCode.descriptorOverflow => 'Descriptor overflow',
        ThreatCode.crcTokenFault => 'CRC / token fault',
        ThreatCode.bitStuffError => 'Bit-stuff error',
        ThreatCode.manualHostKill => 'Manual isolate',
      };

  /// One-line explanation of what tripped (fabric threat table).
  String get detail => switch (this) {
        ThreatCode.noFault => 'Normal operation',
        ThreatCode.unauthorizedHid =>
          'HID interface (class 0x03) on a storage-only port',
        ThreatCode.keystrokeBurst =>
          'Keystrokes faster than the human typing bound',
        ThreatCode.cooldownBurst =>
          'Keystrokes during the post-enumeration cooldown window',
        ThreatCode.descriptorOverflow =>
          'USB descriptor length overflow or mismatch',
        ThreatCode.crcTokenFault => 'USB token or data CRC failure',
        ThreatCode.bitStuffError => 'USB bit-stuffing violation on the wire',
        ThreatCode.manualHostKill => 'Operator isolated this port',
      };

  static ThreatCode fromValue(int value) {
    return ThreatCode.values.firstWhere(
      (code) => code.value == value,
      orElse: () => ThreatCode.noFault,
    );
  }

  static String nameFor(int value) => fromValue(value).name;

  static String summaryFor(int value) => fromValue(value).summary;

  static String detailFor(int value) => fromValue(value).detail;
}

/// Common host UART baud rates for the console picker.
abstract final class SerialBaud {
  static const int defaultRate = 115200;
  static const List<int> choices = [
    9600,
    19200,
    38400,
    57600,
    115200,
    230400,
  ];
}

/// USB class code labels for operator display (bDeviceClass / bInterfaceClass).
abstract final class UsbClass {
  static int? _parse(String hex) {
    final normalized = hex.trim().toLowerCase();
    if (normalized.startsWith('0x')) {
      return int.tryParse(normalized.substring(2), radix: 16);
    }
    return int.tryParse(normalized, radix: 16) ?? int.tryParse(normalized);
  }

  /// Short label for notable classes; null for 0x00 / unknown (show hex only).
  static String? shortNameForHex(String hex) {
    final value = _parse(hex);
    if (value == null || value == 0x00) {
      return null;
    }
    return switch (value) {
      0x01 => 'Audio',
      0x02 => 'CDC',
      0x03 => 'HID',
      0x06 => 'Image',
      0x07 => 'Printer',
      0x08 => 'Storage',
      0x09 => 'Hub',
      0x0A => 'CDC',
      0x0E => 'Video',
      0xE0 => 'Wireless',
      0xFF => 'Vendor',
      _ => null,
    };
  }

  /// Compact single-line value: `0x03 HID` or just `0x00`.
  static String display(String hex) {
    final label = shortNameForHex(hex);
    return label == null ? hex : '$hex $label';
  }
}

enum CommandType {
  isolatePort,
  restorePort,
  clearFault,
  /// Operator confirm for HID-confirm hold → MCU SPI `Pn_CONTROL[5]`.
  confirmHid;

  String get wireName => switch (this) {
        CommandType.isolatePort => 'isolate_port',
        CommandType.restorePort => 'restore_port',
        CommandType.clearFault => 'clear_fault',
        CommandType.confirmHid => 'confirm_hid',
      };

  static CommandType? fromWireName(String name) {
    for (final cmd in CommandType.values) {
      if (cmd.wireName == name) {
        return cmd;
      }
    }
    return null;
  }
}

/// Host → MCU command line: `{"type":"command","cmd":"...","port":N}\n`
class HostCommand {
  const HostCommand({required this.cmd, required this.port});

  final CommandType cmd;
  final int port;

  Map<String, dynamic> toJson() => {
        'type': 'command',
        'cmd': cmd.wireName,
        'port': port,
      };

  String toWireLine() => '${jsonEncode(toJson())}\n';

  static HostCommand fromJson(Map<String, dynamic> json) {
    final parsed = tryParse(json);
    if (parsed == null) {
      throw FormatException('invalid host command: $json');
    }
    return parsed;
  }

  /// Null on bad shape — never throws.
  static HostCommand? tryParse(Map<String, dynamic> json) {
    try {
      final type = json['type'];
      if (type != null && type != 'command') {
        return null;
      }
      final cmd = CommandType.fromWireName(_jsonString(json['cmd']));
      final port = _jsonInt(json['port']);
      if (cmd == null || port == null) {
        return null;
      }
      return HostCommand(cmd: cmd, port: port);
    } on Object {
      return null;
    }
  }
}

class PortStatus {
  const PortStatus({
    required this.port,
    required this.state,
    required this.threatCode,
    required this.vid,
    required this.pid,
    required this.devClass,
    required this.intClass,
  });

  final int port;
  final PortState state;
  final int threatCode;
  final String vid;
  final String pid;
  final String devClass;
  final String intClass;

  PortStatus copyWith({
    PortState? state,
    int? threatCode,
    String? vid,
    String? pid,
    String? devClass,
    String? intClass,
  }) {
    return PortStatus(
      port: port,
      state: state ?? this.state,
      threatCode: threatCode ?? this.threatCode,
      vid: vid ?? this.vid,
      pid: pid ?? this.pid,
      devClass: devClass ?? this.devClass,
      intClass: intClass ?? this.intClass,
    );
  }

  Map<String, dynamic> toJson() => {
        'port': port,
        'state': state.wireName,
        'threat_code': threatCode,
        'vid': vid,
        'pid': pid,
        'dev_class': devClass,
        'int_class': intClass,
      };

  factory PortStatus.fromJson(Map<String, dynamic> json) {
    final port = _jsonInt(json['port']);
    final threat = _jsonInt(json['threat_code']) ?? 0;
    if (port == null) {
      throw FormatException('port status missing port');
    }
    return PortStatus(
      port: port,
      state: PortState.fromWireName(_jsonString(json['state'], 'DISCONNECTED')),
      threatCode: threat,
      vid: _jsonString(json['vid'], '0x0000'),
      pid: _jsonString(json['pid'], '0x0000'),
      devClass: _jsonString(json['dev_class'], '0x00'),
      intClass: _jsonString(json['int_class'], '0x00'),
    );
  }
}

class TelemetryFrame {
  const TelemetryFrame({
    required this.timestampMs,
    required this.ports,
  });

  final int timestampMs;
  final List<PortStatus> ports;

  Map<String, dynamic> toJson() => {
        'timestamp_ms': timestampMs,
        'ports': ports.map((p) => p.toJson()).toList(growable: false),
      };

  factory TelemetryFrame.fromJson(Map<String, dynamic> json) {
    final timestamp = _jsonInt(json['timestamp_ms']);
    final rawPorts = json['ports'];
    if (timestamp == null || rawPorts is! List) {
      throw FormatException('telemetry missing timestamp_ms/ports');
    }
    final ports = <PortStatus>[];
    for (final e in rawPorts) {
      final map = _jsonMap(e);
      if (map == null) {
        throw FormatException('port entry is not an object');
      }
      ports.add(PortStatus.fromJson(map));
    }
    return TelemetryFrame(timestampMs: timestamp, ports: ports);
  }

  /// Parse one newline-delimited telemetry line. Returns null on bad JSON —
  /// never throws (safe for UART byte pumps).
  static TelemetryFrame? tryParseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      final map = _jsonMap(decoded);
      if (map == null) {
        return null;
      }
      return TelemetryFrame.fromJson(map);
    } on Object {
      return null;
    }
  }
}

/// Accumulates UART bytes into newline-delimited [TelemetryFrame]s.
///
/// Bad lines and malformed UTF-8 are skipped; [push] never throws.
class TelemetryLineBuffer {
  final StringBuffer _buf = StringBuffer();

  /// Feed raw UART bytes; returns newly completed frames (may be empty).
  List<TelemetryFrame> push(List<int> data) {
    try {
      _buf.write(utf8.decode(data, allowMalformed: true));
      var content = _buf.toString();
      final out = <TelemetryFrame>[];
      var newline = content.indexOf('\n');
      while (newline >= 0) {
        final line = content.substring(0, newline);
        content = content.substring(newline + 1);
        final frame = TelemetryFrame.tryParseLine(line);
        if (frame != null) {
          out.add(frame);
        }
        newline = content.indexOf('\n');
      }
      _buf
        ..clear()
        ..write(content);
      return out;
    } on Object {
      _buf.clear();
      return const [];
    }
  }

  /// Feed a UTF-8 string (tests / simulators).
  List<TelemetryFrame> pushString(String chunk) =>
      push(Uint8List.fromList(utf8.encode(chunk)));

  void clear() => _buf.clear();
}

class SecurityEvent {
  const SecurityEvent({
    this.id,
    required this.at,
    required this.port,
    required this.threatCode,
    required this.threatName,
    required this.state,
    required this.message,
  });

  /// Drift row id when persisted; null for not-yet-written events.
  final int? id;

  /// Wall-clock time when the console recorded the event (not MCU session ms).
  final DateTime at;

  /// Downstream hub port 0–3. Legacy host-link rows may use [systemPort].
  final int port;
  final int threatCode;
  final String threatName;
  final PortState state;
  final String message;

  /// Marker for legacy host/UART status rows (no longer logged).
  static const int systemPort = -1;

  /// True for host/UART link noise (filtered out of the security log).
  bool get isSystem => port < 0 || isHostLinkMessage(message);

  /// Operator-facing port label (`Port 1` … or `System`).
  String get portLabel => isSystem ? 'System' : 'Port ${port + 1}';

  /// Bold threat title for the log; null when there is no real threat.
  /// Manual isolate is operator action — message alone is enough (no title).
  String? get threatHeadline {
    if (threatCode <= 0 ||
        threatCode == ThreatCode.manualHostKill.value) {
      return null;
    }
    return ThreatCode.summaryFor(threatCode);
  }

  /// Host transport / COM picker messages (not a downstream hub port).
  static bool isHostLinkMessage(String message) {
    final m = message.trimLeft();
    return m.startsWith('UART ') ||
        m.startsWith('Serial port ') ||
        m.startsWith('Reconnect failed') ||
        m.startsWith('Port switch failed') ||
        m.startsWith('Baud rate ');
  }

  /// Normalize legacy DB rows that stored system events as port 0.
  SecurityEvent normalized() {
    if (port < 0 || !isHostLinkMessage(message)) {
      return this;
    }
    return copyWith(port: systemPort);
  }

  SecurityEvent copyWith({int? id, int? port}) {
    return SecurityEvent(
      id: id ?? this.id,
      at: at,
      port: port ?? this.port,
      threatCode: threatCode,
      threatName: threatName,
      state: state,
      message: message,
    );
  }

  /// `YYYY-MM-DD HH:MM:SS` for the event log UI.
  String get formattedAt {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}
