import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_console/protocol.dart';
import 'package:hub_console/serial_device.dart';

/// Tier-1: SerialDevice over PTY + mcu_sim (dummy peer — not PCB).
///
/// `make test` / `make test-serial` set LD_LIBRARY_PATH to the linux bundle
/// lib/ when present. PTY paths often use SerialDevice's dart:io fallback
/// because libserialport rejects PTY termios (EINVAL).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Process pty;
  late Process sim;
  const hostPort = '/tmp/hub_host_test';
  const mcuPort = '/tmp/hub_mcu_test';

  setUpAll(() async {
    final repoGui = Directory.current.path.endsWith('app')
        ? Directory.current.parent.path
        : Directory.current.path;
    final scripts = '$repoGui/scripts';

    pty = await Process.start(
      'python3',
      [
        '$scripts/pty_pair.py',
        '--mcu-link',
        mcuPort,
        '--host-link',
        hostPort,
      ],
      mode: ProcessStartMode.normal,
    );
    pty.stdout.drain<void>();
    pty.stderr.drain<void>();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final ptyDead = await Future.any<int?>([
      pty.exitCode.then<int?>((c) => c),
      Future<int?>.delayed(const Duration(milliseconds: 50), () => null),
    ]);
    if (ptyDead != null) {
      fail('pty_pair exited early ($ptyDead)');
    }

    sim = await Process.start(
      'python3',
      ['$scripts/mcu_sim.py', '--port', mcuPort, '--baud', '115200'],
    );
    sim.stdout.drain<void>();
    sim.stderr.drain<void>();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final earlyExit = await Future.any<int?>([
      sim.exitCode.then<int?>((code) => code),
      Future<int?>.delayed(const Duration(milliseconds: 50), () => null),
    ]);
    if (earlyExit != null) {
      fail('mcu_sim exited early ($earlyExit)');
    }
  });

  tearDownAll(() async {
    sim.kill();
    pty.kill();
    try {
      await File(hostPort).delete();
    } catch (_) {}
    try {
      await File(mcuPort).delete();
    } catch (_) {}
  });

  test('SerialDevice reads telemetry and applies isolate/restore/clear', () async {
    final link = File(hostPort);
    expect(await link.exists(), isTrue, reason: 'missing $hostPort');
    final resolved = link.resolveSymbolicLinksSync();
    expect(
      File(resolved).existsSync(),
      isTrue,
      reason: 'broken PTY symlink $hostPort -> $resolved',
    );

    final device = SerialDevice(portPath: hostPort);
    final frames = <TelemetryFrame>[];
    final sub = device.frames.listen(frames.add);

    device.start();
    expect(device.mode, anyOf('serial', 'serial_error'));
    if (device.mode == 'serial_error') {
      fail('serial open failed: ${device.errorMessage}');
    }

    TelemetryFrame? first;
    for (var i = 0; i < 50 && first == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      first = device.getTelemetry();
    }
    expect(first, isNotNull, reason: 'expected telemetry from mcu_sim');
    expect(first!.ports[0].state, PortState.authorized);

    device.isolatePort(1);
    PortStatus? isolated;
    for (var i = 0; i < 50 && isolated?.state != PortState.manualBlocked; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      isolated = device.getTelemetry()?.ports[1];
    }
    expect(isolated?.state, PortState.manualBlocked);
    expect(isolated?.threatCode, 7);

    device.clearFault(1);
    PortStatus? cleared;
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      cleared = device.getTelemetry()?.ports[1];
      if (cleared?.threatCode == 0 &&
          cleared?.state == PortState.manualBlocked) {
        break;
      }
    }
    expect(cleared?.threatCode, 0);
    expect(cleared?.state, PortState.manualBlocked);

    device.restorePort(1);
    PortStatus? restored;
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      restored = device.getTelemetry()?.ports[1];
      if (restored?.state == PortState.authorized) {
        break;
      }
    }
    expect(restored?.state, PortState.authorized);

    await sub.cancel();
    device.dispose();
    expect(frames, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
