import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_console/protocol.dart';

/// Fixtures from Docs/firmwmare_slop.md §4.
void main() {
  group('TelemetryFrame', () {
    const fixture = '''
{
  "timestamp_ms": 14820,
  "ports": [
    {
      "port": 0,
      "state": "AUTHORIZED",
      "threat_code": 0,
      "vbus_mv": 5020,
      "current_ma": 42,
      "vid": "0x0781",
      "pid": "0x5583",
      "dev_class": "0x00",
      "int_class": "0x08"
    },
    {
      "port": 1,
      "state": "QUARANTINED",
      "threat_code": 1,
      "vbus_mv": 0,
      "current_ma": 0,
      "vid": "0x046D",
      "pid": "0xC31C",
      "dev_class": "0x00",
      "int_class": "0x03"
    }
  ]
}
''';

    test('fromJson parses firmware doc fixture', () {
      final frame = TelemetryFrame.fromJson(
        jsonDecode(fixture) as Map<String, dynamic>,
      );
      expect(frame.timestampMs, 14820);
      expect(frame.ports, hasLength(2));

      final p0 = frame.ports[0];
      expect(p0.port, 0);
      expect(p0.state, PortState.authorized);
      expect(p0.threatCode, 0);
      expect(p0.vbusMv, 5020);
      expect(p0.currentMa, 42);
      expect(p0.vid, '0x0781');
      expect(p0.pid, '0x5583');
      expect(p0.devClass, '0x00');
      expect(p0.intClass, '0x08');

      final p1 = frame.ports[1];
      expect(p1.state, PortState.quarantined);
      expect(p1.threatCode, 1);
    });

    test('toJson round-trips', () {
      final original = TelemetryFrame.fromJson(
        jsonDecode(fixture) as Map<String, dynamic>,
      );
      final again = TelemetryFrame.fromJson(original.toJson());
      expect(again.timestampMs, original.timestampMs);
      expect(again.ports[0].vid, original.ports[0].vid);
      expect(again.ports[1].threatCode, original.ports[1].threatCode);
    });

    test('tryParseLine tolerates whitespace and drops bad JSON', () {
      final line = '${fixture.replaceAll(RegExp(r'\s+'), ' ').trim()}\n';
      final ok = TelemetryFrame.tryParseLine(line);
      expect(ok, isNotNull);
      expect(ok!.ports[0].state, PortState.authorized);

      expect(TelemetryFrame.tryParseLine(''), isNull);
      expect(TelemetryFrame.tryParseLine('not-json\n'), isNull);
      expect(TelemetryFrame.tryParseLine('[1,2,3]'), isNull);
    });
  });

  group('HostCommand', () {
    test('serializes isolate_port wire line', () {
      final cmd = HostCommand(cmd: CommandType.isolatePort, port: 2);
      expect(
        cmd.toJson(),
        {'type': 'command', 'cmd': 'isolate_port', 'port': 2},
      );
      expect(cmd.toWireLine(), '{"type":"command","cmd":"isolate_port","port":2}\n');
    });

    test('parses restore and clear', () {
      final restore = HostCommand.fromJson({
        'type': 'command',
        'cmd': 'restore_port',
        'port': 1,
      });
      expect(restore.cmd, CommandType.restorePort);
      expect(restore.port, 1);

      final clear = HostCommand.fromJson({
        'cmd': 'clear_fault',
        'port': 0,
      });
      expect(clear.cmd, CommandType.clearFault);
    });

    test('all command wire names', () {
      expect(CommandType.isolatePort.wireName, 'isolate_port');
      expect(CommandType.restorePort.wireName, 'restore_port');
      expect(CommandType.clearFault.wireName, 'clear_fault');
    });
  });

  group('PortState / ThreatCode', () {
    test('fromWireName covers all states', () {
      for (final state in PortState.values) {
        expect(PortState.fromWireName(state.wireName), state);
      }
      expect(PortState.fromWireName('NOPE'), PortState.disconnected);
    });

    test('threat code names', () {
      expect(ThreatCode.nameFor(2), 'KEYSTROKE_BURST');
      expect(ThreatCode.nameFor(7), 'MANUAL_HOST_KILL');
      expect(ThreatCode.fromValue(99), ThreatCode.noFault);
    });
  });
}
