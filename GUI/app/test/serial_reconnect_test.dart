import 'package:flutter_test/flutter_test.dart';
import 'package:hub_console/serial_device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('commands never throw when port cannot open', () {
    // Path that neither libserialport nor dart:io can open (not creatable).
    final device = SerialDevice(portPath: '/dev/null/not_a_serial_port');
    device.start();

    expect(device.mode, anyOf('serial_error', 'serial_reconnecting'));
    expect(device.supportsReconnect, isTrue);

    expect(() => device.isolatePort(1), returnsNormally);
    expect(() => device.restorePort(1), returnsNormally);
    expect(() => device.clearFault(1), returnsNormally);

    final iso = device.isolatePort(0);
    expect(iso.$3, contains('link down'));

    expect(() => device.reconnect(), returnsNormally);
    device.dispose();
  });

  test('dispose is idempotent after failed open', () {
    final device = SerialDevice(portPath: '/dev/null/not_a_serial_port');
    device.start();
    device.dispose();
    expect(() => device.dispose(), returnsNormally);
  });
}
