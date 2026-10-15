import 'hub_device.dart';
import 'serial_device.dart';

/// Desktop: create a [SerialDevice] from dart-defines.
HubDevice createSerialDeviceFromEnvironment() {
  const port = String.fromEnvironment('SERIAL_PORT');
  const baud = int.fromEnvironment('SERIAL_BAUD', defaultValue: 115200);
  if (port.isEmpty) {
    throw StateError(
      'HUB_MODE=serial requires --dart-define=SERIAL_PORT=... '
      '(e.g. /tmp/hub_host, /dev/ttyUSB0, or COM3 on Windows)',
    );
  }
  return SerialDevice(portPath: port, baudRate: baud);
}
