import 'package:flutter_test/flutter_test.dart';
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
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(hub1.events, isNotEmpty);
    final savedMessage = hub1.events.last.message;
    hub1.dispose();

    // Same store instance simulates reload after process restart.
    final hub2 = HubService(
      device: MockDevice(),
      eventLog: sharedDb,
      maxEvents: 200,
    );
    await hub2.start();
    expect(hub2.events, isNotEmpty);
    expect(hub2.events.last.message, savedMessage);
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
}
