import 'package:flutter_test/flutter_test.dart';
import 'package:hub_console/db/event_export.dart';
import 'package:hub_console/hub_service.dart';
import 'package:hub_console/mock_device.dart';
import 'package:hub_console/protocol.dart';

import 'support/memory_event_log.dart';

void main() {
  test('SecurityEvent.formattedAt is date and wall clock', () {
    final event = SecurityEvent(
      at: DateTime(2026, 10, 8, 15, 30, 45),
      port: 0,
      threatCode: 0,
      threatName: 'NO_FAULT',
      state: PortState.authorized,
      message: 'test',
    );
    expect(event.formattedAt, '2026-10-08 15:30:45');
  });

  test('system events hide NO_FAULT title and use System port label', () {
    final system = SecurityEvent(
      at: DateTime(2026, 11, 18, 15, 54, 20),
      port: SecurityEvent.systemPort,
      threatCode: ThreatCode.noFault.value,
      threatName: ThreatCode.nameFor(ThreatCode.noFault.value),
      state: PortState.disconnected,
      message: 'UART link restored (COM3)',
    );
    expect(system.isSystem, isTrue);
    expect(system.portLabel, 'System');
    expect(system.threatHeadline, isNull);

    // Legacy DB rows stored UART events as port 0 ("Port 1" in UI).
    final legacy = SecurityEvent(
      at: DateTime(2026, 11, 18, 15, 54, 20),
      port: 0,
      threatCode: ThreatCode.noFault.value,
      threatName: 'NO_FAULT',
      state: PortState.disconnected,
      message: 'UART link restored (COM3)',
    );
    expect(legacy.isSystem, isTrue);
    expect(legacy.portLabel, 'System');
    expect(legacy.normalized().port, SecurityEvent.systemPort);

    final threat = SecurityEvent(
      at: DateTime(2026, 11, 18, 15, 54, 21),
      port: 1,
      threatCode: ThreatCode.keystrokeBurst.value,
      threatName: ThreatCode.nameFor(ThreatCode.keystrokeBurst.value),
      state: PortState.quarantined,
      message: 'burst',
    );
    expect(threat.isSystem, isFalse);
    expect(threat.portLabel, 'Port 2');
    expect(threat.threatHeadline, ThreatCode.keystrokeBurst.summary);

    final manual = SecurityEvent(
      at: DateTime(2026, 11, 18, 16, 40),
      port: 1,
      threatCode: ThreatCode.manualHostKill.value,
      threatName: ThreatCode.nameFor(ThreatCode.manualHostKill.value),
      state: PortState.manualBlocked,
      message: 'Manually isolated by operator',
    );
    expect(manual.threatHeadline, isNull);
  });

  test('EventLogStore persists and reloads last N events', () async {
    final sharedDb = memoryEventLogStore();
    await sharedDb.open();

    final hub1 = HubService(
      device: MockDevice(),
      eventLog: sharedDb,
      maxEvents: 200,
    );
    await hub1.start();
    hub1.handleCommand(CommandType.isolatePort, 1);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(hub1.events, isNotEmpty);
    // Dual log: command sent + hardware Changed to MANUAL_BLOCKED.
    expect(
      hub1.events.map((e) => e.message),
      contains('Isolate command sent'),
    );
    final savedMessages = hub1.events.map((e) => e.message).toSet();
    hub1.dispose();

    // Same store instance simulates reload after process restart.
    final hub2 = HubService(
      device: MockDevice(),
      eventLog: sharedDb,
      maxEvents: 200,
    );
    await hub2.start();
    expect(hub2.events, isNotEmpty);
    expect(
      hub2.events.map((e) => e.message).toSet().intersection(savedMessages),
      isNotEmpty,
    );
    expect(hub2.events.last.at, isA<DateTime>());
    hub2.dispose();
    await sharedDb.close();
  });

  test('EventLogStore trimTo keeps newest 200', () async {
    final store = memoryEventLogStore();
    await store.open();
    for (var i = 0; i < 205; i++) {
      await store.append(
        SecurityEvent(
          at: DateTime(2026, 1, 1).add(Duration(seconds: i)),
          port: 0,
          threatCode: 0,
          threatName: 'NO_FAULT',
          state: PortState.authorized,
          message: 'event-$i',
        ),
      );
    }
    await store.trimTo(200);
    final loaded = await store.loadRecent(200);
    expect(loaded, hasLength(200));
    expect(loaded.first.message, 'event-5');
    expect(loaded.last.message, 'event-204');
    await store.close();
  });

  test('EventLogStore clearAll and deleteById', () async {
    final store = memoryEventLogStore();
    await store.open();
    final id0 = await store.append(
      SecurityEvent(
        at: DateTime(2026, 1, 1),
        port: 0,
        threatCode: 0,
        threatName: 'NO_FAULT',
        state: PortState.authorized,
        message: 'a',
      ),
    );
    final id1 = await store.append(
      SecurityEvent(
        at: DateTime(2026, 1, 2),
        port: 1,
        threatCode: 2,
        threatName: 'HID_BURST',
        state: PortState.quarantined,
        message: 'b',
      ),
    );
    await store.deleteById(id0);
    var loaded = await store.loadRecent(200);
    expect(loaded, hasLength(1));
    expect(loaded.single.id, id1);
    expect(loaded.single.message, 'b');

    await store.clearAll();
    loaded = await store.loadRecent(200);
    expect(loaded, isEmpty);
    await store.close();
  });

  test('eventsToCsv / eventsFromCsv round-trip', () {
    final original = [
      SecurityEvent(
        id: 3,
        at: DateTime(2026, 10, 15, 12, 0, 0),
        port: 1,
        threatCode: 2,
        threatName: 'KEYSTROKE_BURST',
        state: PortState.quarantined,
        message: 'burst on port 1',
      ),
    ];
    final parsed = eventsFromCsv(eventsToCsv(original));
    expect(parsed, hasLength(1));
    expect(parsed.single.port, 1);
    expect(parsed.single.threatCode, 2);
    expect(parsed.single.threatName, 'KEYSTROKE_BURST');
    expect(parsed.single.state, PortState.quarantined);
    expect(parsed.single.message, 'burst on port 1');
  });

  test('HubService clearAllEvents and deleteEvent', () async {
    final store = memoryEventLogStore();
    final hub = HubService(
      device: MockDevice(),
      eventLog: store,
      maxEvents: 200,
    );
    await hub.start();
    hub.handleCommand(CommandType.isolatePort, 0);
    hub.handleCommand(CommandType.isolatePort, 1);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(hub.events.length, greaterThanOrEqualTo(2));
    final id = hub.events.firstWhere((e) => e.id != null).id!;
    await hub.deleteEvent(id);
    expect(hub.events.any((e) => e.id == id), isFalse);
    await hub.clearAllEvents();
    expect(hub.events, isEmpty);
    expect(await store.loadRecent(200), isEmpty);
    hub.dispose();
    await store.close();
  });
}
