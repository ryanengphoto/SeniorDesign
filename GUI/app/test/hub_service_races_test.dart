import 'package:flutter_test/flutter_test.dart';
import 'package:hub_console/hub_service.dart';
import 'package:hub_console/protocol.dart';

import 'support/memory_event_log.dart';
import 'support/scripted_device.dart';

PortStatus _port(
  int id,
  PortState state, {
  int threat = 0,
  String vid = '0x046D',
  String pid = '0xC31C',
  String intClass = '0x03',
}) {
  return PortStatus(
    port: id,
    state: state,
    threatCode: threat,
    vid: vid,
    pid: pid,
    devClass: '0x00',
    intClass: intClass,
  );
}

List<PortStatus> _four(PortStatus p0) => [
      p0,
      _port(1, PortState.disconnected, vid: '0x0000', pid: '0x0000'),
      _port(2, PortState.disconnected, vid: '0x0000', pid: '0x0000'),
      _port(3, PortState.disconnected, vid: '0x0000', pid: '0x0000'),
    ];

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  test('confirm_hid logs command and suppresses late PENDING after AUTHORIZED snapshot',
      () async {
    final device = ScriptedDevice(initialPorts: _four(_port(0, PortState.authorized)));
    final hub = HubService(device: device, eventLog: memoryEventLogStore());
    await hub.start();
    device.emit();
    await _settle();

    // Device already PENDING in hardware, but host has not ingested that frame yet.
    device.setPort(_port(0, PortState.pendingHidConfirm));
    hub.handleCommand(CommandType.confirmHid, 0);
    await _settle();
    expect(
      hub.events.map((e) => e.message),
      contains('Confirm HID command sent'),
    );

    // Late PENDING while snapshot is still AUTHORIZED must not log "waiting".
    device.setPort(_port(0, PortState.pendingHidConfirm));
    device.emit();
    await _settle();
    expect(
      hub.events.where((e) => e.message.contains('waiting for operator')),
      isEmpty,
    );

    // Observed AUTHORIZED after confirm (snapshot still AUTHORIZED → no extra change log).
    device.setPort(_port(0, PortState.authorized));
    device.emit();
    await _settle();
    expect(
      hub.events.where((e) => e.message == 'Changed to AUTHORIZED'),
      isEmpty,
    );

    hub.dispose();
  });

  test('confirm_hid dual-logs command + Changed to AUTHORIZED when snapshot was PENDING',
      () async {
    final device = ScriptedDevice(
      initialPorts: _four(_port(0, PortState.pendingHidConfirm)),
    );
    final hub = HubService(device: device, eventLog: memoryEventLogStore());
    await hub.start();
    device.emit();
    await _settle();

    hub.handleCommand(CommandType.confirmHid, 0);
    await _settle();
    expect(
      hub.events.map((e) => e.message),
      contains('Confirm HID command sent'),
    );

    device.setPort(_port(0, PortState.authorized));
    device.emit();
    await _settle();
    expect(
      hub.events.map((e) => e.message),
      containsAll(['Confirm HID command sent', 'Changed to AUTHORIZED']),
    );

    hub.dispose();
  });

  test('isolate logs command + MANUAL_BLOCKED; suppresses stale AUTHORIZED',
      () async {
    final device = ScriptedDevice(initialPorts: _four(_port(0, PortState.authorized)));
    final hub = HubService(device: device, eventLog: memoryEventLogStore());
    await hub.start();
    device.emit();
    await _settle();

    hub.handleCommand(CommandType.isolatePort, 0);
    await _settle();
    expect(
      hub.events.map((e) => e.message),
      contains('Isolate command sent'),
    );

    // Hardware MANUAL_BLOCKED updates snapshot.
    device.setPort(
      _port(0, PortState.manualBlocked, threat: ThreatCode.manualHostKill.value),
    );
    device.emit();
    await _settle();
    expect(
      hub.events.map((e) => e.message),
      contains('Changed to MANUAL_BLOCKED'),
    );

    // Late AUTHORIZED after isolate must not flip the log back.
    device.setPort(_port(0, PortState.authorized));
    device.emit();
    await _settle();
    expect(
      hub.events.where((e) => e.message == 'Changed to AUTHORIZED'),
      isEmpty,
    );

    // Restore clears suppress; AUTHORIZED may log again.
    hub.handleCommand(CommandType.restorePort, 0);
    await _settle();
    device.setPort(_port(0, PortState.authorized));
    device.emit();
    await _settle();
    expect(
      hub.events.where((e) => e.message == 'Changed to AUTHORIZED'),
      isNotEmpty,
    );

    hub.dispose();
  });

  test('isolate/restore clears confirm suppress so later PENDING can log', () async {
    final device = ScriptedDevice(initialPorts: _four(_port(0, PortState.authorized)));
    final hub = HubService(device: device, eventLog: memoryEventLogStore());
    await hub.start();
    device.emit();
    await _settle();

    // Arm confirm suppress with AUTHORIZED snapshot (same race as first test).
    device.setPort(_port(0, PortState.pendingHidConfirm));
    hub.handleCommand(CommandType.confirmHid, 0);
    await _settle();
    device.setPort(_port(0, PortState.pendingHidConfirm));
    device.emit();
    await _settle();
    expect(
      hub.events.where((e) => e.message.contains('waiting for operator')),
      isEmpty,
    );

    // Isolate must drop that suppress so a post-restore PENDING is visible.
    hub.handleCommand(CommandType.isolatePort, 0);
    await _settle();
    device.setPort(
      _port(0, PortState.manualBlocked, threat: ThreatCode.manualHostKill.value),
    );
    device.emit();
    await _settle();

    hub.handleCommand(CommandType.restorePort, 0);
    await _settle();
    device.setPort(_port(0, PortState.pendingHidConfirm));
    device.emit();
    await _settle();
    expect(
      hub.events.map((e) => e.message),
      contains('HID device waiting for operator confirm'),
    );

    hub.dispose();
  });

  test('attach then pending logs Device attached then HID waiting', () async {
    final device = ScriptedDevice(
      initialPorts: _four(
        _port(0, PortState.disconnected, vid: '0x0000', pid: '0x0000'),
      ),
    );
    final hub = HubService(device: device, eventLog: memoryEventLogStore());
    await hub.start();
    device.emit();
    await _settle();

    device.setPort(_port(0, PortState.authorized));
    device.emit();
    await _settle();
    expect(hub.events.map((e) => e.message), contains('Device attached'));

    device.setPort(_port(0, PortState.pendingHidConfirm));
    device.emit();
    await _settle();
    expect(
      hub.events.map((e) => e.message),
      contains('HID device waiting for operator confirm'),
    );

    hub.dispose();
  });

  test('system / UART host-link events are never kept in the security log',
      () async {
    final store = memoryEventLogStore();
    await store.open();
    await store.append(
      SecurityEvent(
        at: DateTime(2026, 11, 18, 12, 0, 0),
        port: SecurityEvent.systemPort,
        threatCode: ThreatCode.noFault.value,
        threatName: 'NO_FAULT',
        state: PortState.disconnected,
        message: 'UART link restored (COM3)',
      ),
    );
    await store.append(
      SecurityEvent(
        at: DateTime(2026, 11, 18, 12, 0, 1),
        port: 0,
        threatCode: ThreatCode.noFault.value,
        threatName: 'NO_FAULT',
        state: PortState.disconnected,
        message: 'Baud rate changed to 115200',
      ),
    );
    await store.append(
      SecurityEvent(
        at: DateTime(2026, 11, 18, 12, 0, 2),
        port: 1,
        threatCode: ThreatCode.keystrokeBurst.value,
        threatName: ThreatCode.nameFor(ThreatCode.keystrokeBurst.value),
        state: PortState.quarantined,
        message: 'Keystroke burst — quarantined',
      ),
    );

    final device = ScriptedDevice();
    final hub = HubService(device: device, eventLog: store);
    await hub.start();
    await _settle();

    expect(hub.events, hasLength(1));
    expect(hub.events.single.message, 'Keystroke burst — quarantined');
    expect(hub.events.single.isSystem, isFalse);

    hub.dispose();
    await store.close();
  });

  test('keystroke burst telemetry uses single-line quarantine message', () async {
    final device = ScriptedDevice(initialPorts: _four(_port(0, PortState.authorized)));
    final hub = HubService(device: device, eventLog: memoryEventLogStore());
    await hub.start();
    device.emit();
    await _settle();

    device.setPort(
      _port(
        0,
        PortState.quarantined,
        threat: ThreatCode.keystrokeBurst.value,
      ),
    );
    device.emit();
    await _settle();

    final burst = hub.events.lastWhere(
      (e) => e.threatCode == ThreatCode.keystrokeBurst.value,
    );
    expect(burst.message, '${ThreatCode.keystrokeBurst.summary} — quarantined');
    expect(burst.message.toLowerCase(), isNot(contains('port 1')));

    hub.dispose();
  });
}
