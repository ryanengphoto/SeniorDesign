import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_console/db/event_export.dart';
import 'package:hub_console/hub_service.dart';
import 'package:hub_console/protocol.dart';
import 'package:hub_console/serial_device.dart';

import 'support/memory_event_log.dart';
import 'support/scripted_device.dart';

String _validPortJson({
  int port = 0,
  String state = 'AUTHORIZED',
  Object threat = 0,
  Object vid = '0x0781',
  Object pid = '0x5583',
}) {
  return jsonEncode({
    'port': port,
    'state': state,
    'threat_code': threat,
    'vid': vid,
    'pid': pid,
    'dev_class': '0x00',
    'int_class': '0x08',
  });
}

String _validFrameJson({Object timestamp = 1000, List<Object>? ports}) {
  return jsonEncode({
    'timestamp_ms': timestamp,
    'ports': ports ??
        [
          jsonDecode(_validPortJson()),
        ],
  });
}

void main() {
  group('TelemetryFrame.tryParseLine never throws', () {
    final garbage = <String>[
      '',
      '   ',
      '\n',
      'not-json',
      '{',
      '}',
      '[]',
      '[1,2,3]',
      'null',
      'true',
      '"string"',
      '123',
      '{"timestamp_ms":1}',
      '{"ports":[]}',
      '{"timestamp_ms":null,"ports":[]}',
      '{"timestamp_ms":1,"ports":null}',
      '{"timestamp_ms":1,"ports":"nope"}',
      '{"timestamp_ms":1,"ports":[null]}',
      '{"timestamp_ms":1,"ports":[1]}',
      '{"timestamp_ms":1,"ports":[{}]}',
      '{"timestamp_ms":1,"ports":[{"port":"x"}]}',
      // note: {"timestamp_ms":1,"ports":[]} is intentionally valid (empty frame)
      '{broken',
      '{"timestamp_ms":1,"ports":[{"port":0,"state":AUTHORIZED}]}', // unquoted
      '{"a":\u0000}',
      '\x00\x01\x02\n',
      'HTTP/1.1 200 OK',
      '<html>',
      '{"type":"command","cmd":"isolate_port","port":0}', // command, not telemetry
    ];

    test('hand-picked garbage returns null', () {
      for (final line in garbage) {
        expect(
          () => TelemetryFrame.tryParseLine(line),
          returnsNormally,
          reason: 'line=$line',
        );
        expect(TelemetryFrame.tryParseLine(line), isNull, reason: 'line=$line');
      }
    });

    test('random byte strings never throw (fuzz)', () {
      final rng = Random(42);
      for (var i = 0; i < 400; i++) {
        final len = rng.nextInt(120);
        final buf = StringBuffer();
        for (var j = 0; j < len; j++) {
          buf.writeCharCode(rng.nextInt(256));
        }
        final line = buf.toString();
        expect(() => TelemetryFrame.tryParseLine(line), returnsNormally);
      }
    });

    test('coerces numeric strings / doubles from lenient peers', () {
      final line = _validFrameJson(
        timestamp: '14820',
        ports: [
          jsonDecode(
            _validPortJson(threat: 2.0, vid: 1921, pid: '0xC31C'),
          ),
        ],
      );
      final frame = TelemetryFrame.tryParseLine(line);
      expect(frame, isNotNull);
      expect(frame!.timestampMs, 14820);
      expect(frame.ports.single.threatCode, 2);
      expect(frame.ports.single.vid, '1921');
    });

    test('unknown state becomes DISCONNECTED, not a crash', () {
      final line = _validFrameJson(
        ports: [jsonDecode(_validPortJson(state: 'WEIRD_STATE'))],
      );
      final frame = TelemetryFrame.tryParseLine(line);
      expect(frame, isNotNull);
      expect(frame!.ports.single.state, PortState.disconnected);
    });

    test('CRLF and partial whitespace still parse', () {
      final body = _validFrameJson();
      expect(TelemetryFrame.tryParseLine('$body\r'), isNotNull);
      expect(TelemetryFrame.tryParseLine('  $body  \r\n'), isNotNull);
    });
  });

  group('TelemetryLineBuffer', () {
    test('assembles split frames and skips junk lines', () {
      final buf = TelemetryLineBuffer();
      final good = '${_validFrameJson()}\n';

      expect(buf.pushString('garbage\n'), isEmpty);
      expect(buf.pushString(good.substring(0, 20)), isEmpty);
      final frames = buf.pushString(good.substring(20));
      expect(frames, hasLength(1));
      expect(frames.single.timestampMs, 1000);

      // Junk line between complete frames is skipped.
      expect(buf.pushString('still-bad\n${_validFrameJson()}\n'), hasLength(1));
    });

    test('malformed UTF-8 bytes never throw', () {
      final buf = TelemetryLineBuffer();
      expect(
        () => buf.push(Uint8List.fromList([0xFF, 0xFE, 0x80, 0x0A])),
        returnsNormally,
      );
      expect(buf.push(Uint8List.fromList([0xFF, 0xFE, 0x80, 0x0A])), isEmpty);
    });

    test('binary noise then a valid frame still yields the frame', () {
      final buf = TelemetryLineBuffer();
      final noise = Uint8List.fromList(List<int>.generate(64, (i) => i));
      buf.push(noise);
      buf.pushString('\n');
      final frames = buf.pushString('${_validFrameJson()}\n');
      expect(frames, hasLength(1));
    });
  });

  group('SerialDevice RX inject', () {
    test('garbage UART bytes do not crash or publish frames', () async {
      final device = SerialDevice(portPath: 'COM9');
      final frames = <TelemetryFrame>[];
      final sub = device.frames.listen(frames.add);

      final wire = '${_validFrameJson()}\n';
      expect(TelemetryFrame.tryParseLine(wire.trim()), isNotNull);

      // Good frame alone.
      device.injectRxForTest(utf8.encode(wire));
      await Future<void>.delayed(Duration.zero);
      expect(device.getTelemetry()?.timestampMs, 1000);
      expect(frames, hasLength(1));

      // Garbage must not throw or clear the last good telemetry.
      expect(
        () => device.injectRxForTest(utf8.encode('not-json\n{broken\n')),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);
      expect(frames, hasLength(1));
      expect(device.getTelemetry()?.timestampMs, 1000);

      // Another good frame after junk.
      device.injectRxForTest(utf8.encode(wire));
      await Future<void>.delayed(Duration.zero);
      expect(frames, hasLength(2));

      await sub.cancel();
      device.dispose();
    });
  });

  group('HubService stays up under bad traffic', () {
    test('commands still work after odd telemetry', () async {
      final device = ScriptedDevice(
        initialPorts: [
          const PortStatus(
            port: 0,
            state: PortState.authorized,
            threatCode: 0,
            vid: '0x0781',
            pid: '0x5583',
            devClass: '0x00',
            intClass: '0x08',
          ),
          const PortStatus(
            port: 1,
            state: PortState.disconnected,
            threatCode: 0,
            vid: '0x0000',
            pid: '0x0000',
            devClass: '0x00',
            intClass: '0x00',
          ),
          const PortStatus(
            port: 2,
            state: PortState.disconnected,
            threatCode: 0,
            vid: '0x0000',
            pid: '0x0000',
            devClass: '0x00',
            intClass: '0x00',
          ),
          const PortStatus(
            port: 3,
            state: PortState.disconnected,
            threatCode: 0,
            vid: '0x0000',
            pid: '0x0000',
            devClass: '0x00',
            intClass: '0x00',
          ),
        ],
      );
      final hub = HubService(device: device, eventLog: memoryEventLogStore());
      await hub.start();
      device.emit();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(() => hub.handleCommand(CommandType.isolatePort, 0), returnsNormally);
      expect(() => hub.handleCommand(CommandType.restorePort, 0), returnsNormally);
      expect(() => hub.handleCommand(CommandType.clearFault, 99), returnsNormally);

      hub.dispose();
    });
  });

  group('CSV import resilience', () {
    test('garbage CSV never throws', () {
      final samples = <String>[
        '',
        'not,csv',
        'id,at,port,threat_code,threat_name,state,message\n,,,,,\n',
        'id,at,port,threat_code,threat_name,state,message\n'
            '1,not-a-date,99,abc,NAME,NOPE,"msg with ""quotes"""\n'
            'broken-line-only\n'
            '2,2026-01-01 00:00:00,1,2,KEYSTROKE_BURST,QUARANTINED,ok\n',
      ];
      for (final csv in samples) {
        expect(() => eventsFromCsv(csv), returnsNormally);
      }
      final parsed = eventsFromCsv(samples.last);
      expect(parsed.any((e) => e.message == 'ok'), isTrue);
    });
  });

  group('HostCommand.tryParse', () {
    test('rejects junk without throwing', () {
      expect(HostCommand.tryParse({}), isNull);
      expect(HostCommand.tryParse({'cmd': 'nope', 'port': 0}), isNull);
      expect(HostCommand.tryParse({'type': 'telemetry', 'cmd': 'isolate_port', 'port': 0}), isNull);
      expect(
        HostCommand.tryParse({'cmd': 'isolate_port', 'port': '2'}),
        isA<HostCommand>(),
      );
    });
  });
}
