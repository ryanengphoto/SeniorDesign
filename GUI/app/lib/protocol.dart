/// Host ↔ hub protocol models.
///
/// Keep aligned with `Docs/firmwmare_slop.md` and `Docs/fabric_slop.md`.
library;

import 'dart:convert';

enum PortState {
  disconnected,
  enumerating,
  authorized,
  quarantined,
  manualBlocked;

  String get wireName => switch (this) {
        PortState.disconnected => 'DISCONNECTED',
        PortState.enumerating => 'ENUMERATING',
        PortState.authorized => 'AUTHORIZED',
        PortState.quarantined => 'QUARANTINED',
        PortState.manualBlocked => 'MANUAL_BLOCKED',
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

  static ThreatCode fromValue(int value) {
    return ThreatCode.values.firstWhere(
      (code) => code.value == value,
      orElse: () => ThreatCode.noFault,
    );
  }

  static String nameFor(int value) => fromValue(value).name;
}

enum CommandType {
  isolatePort,
  restorePort,
  clearFault;

  String get wireName => switch (this) {
        CommandType.isolatePort => 'isolate_port',
        CommandType.restorePort => 'restore_port',
        CommandType.clearFault => 'clear_fault',
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
    required this.vbusMv,
    required this.currentMa,
    required this.vid,
    required this.pid,
    required this.devClass,
    required this.intClass,
  });

  final int port;
  final PortState state;
  final int threatCode;
  final int vbusMv;
  final int currentMa;
  final String vid;
  final String pid;
  final String devClass;
  final String intClass;

  PortStatus copyWith({
    PortState? state,
    int? threatCode,
    int? vbusMv,
    int? currentMa,
    String? vid,
    String? pid,
    String? devClass,
    String? intClass,
  }) {
    return PortStatus(
      port: port,
      state: state ?? this.state,
      threatCode: threatCode ?? this.threatCode,
      vbusMv: vbusMv ?? this.vbusMv,
      currentMa: currentMa ?? this.currentMa,
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
        'vbus_mv': vbusMv,
        'current_ma': currentMa,
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
      vbusMv: json['vbus_mv'] as int,
      currentMa: json['current_ma'] as int,
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
    required this.at,
    required this.port,
    required this.threatCode,
    required this.threatName,
    required this.state,
    required this.message,
  });

  /// Wall-clock time when the console recorded the event (not MCU session ms).
  final DateTime at;
  final int port;
  final int threatCode;
  final String threatName;
  final PortState state;
  final String message;

  /// `YYYY-MM-DD HH:MM:SS` for the event log UI.
  String get formattedAt {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}
