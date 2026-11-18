/// Host ↔ hub protocol models.
///
/// Keep aligned with `Docs/firmwmare_slop.md` and `Docs/fabric_slop.md`.
library;

import 'dart:convert';

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
    final type = json['type'];
    if (type != null && type != 'command') {
      throw FormatException('expected type=command, got $type');
    }
    final cmdName = json['cmd'] as String;
    final cmd = CommandType.fromWireName(cmdName);
    if (cmd == null) {
      throw FormatException('unknown cmd: $cmdName');
    }
    return HostCommand(cmd: cmd, port: json['port'] as int);
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
    return PortStatus(
      port: json['port'] as int,
      state: PortState.fromWireName(json['state'] as String),
      threatCode: json['threat_code'] as int,
      vid: json['vid'] as String,
      pid: json['pid'] as String,
      devClass: json['dev_class'] as String,
      intClass: json['int_class'] as String,
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
    final rawPorts = json['ports'] as List<dynamic>;
    return TelemetryFrame(
      timestampMs: json['timestamp_ms'] as int,
      ports: rawPorts
          .map((e) => PortStatus.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  /// Parse one newline-delimited telemetry line. Returns null on bad JSON.
  static TelemetryFrame? tryParseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return TelemetryFrame.fromJson(decoded);
    } on Object {
      return null;
    }
  }
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
  final int port;
  final int threatCode;
  final String threatName;
  final PortState state;
  final String message;

  SecurityEvent copyWith({int? id}) {
    return SecurityEvent(
      id: id ?? this.id,
      at: at,
      port: port,
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
