import 'hub_device.dart';
import 'serial_device.dart';

/// Desktop: create a [SerialDevice] from dart-defines.
///
/// [SERIAL_PORT] is optional — leave empty and pick a COM/tty in the UI.
HubDevice createSerialDeviceFromEnvironment() {
  const port = String.fromEnvironment('SERIAL_PORT');
  const baud = int.fromEnvironment('SERIAL_BAUD', defaultValue: 115200);
  return SerialDevice(portPath: port, baudRate: baud);
}
