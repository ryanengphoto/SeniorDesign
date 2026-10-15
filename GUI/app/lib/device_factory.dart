import 'device_factory_io.dart'
    if (dart.library.html) 'device_factory_web.dart' as serial_factory;
import 'hub_device.dart';
import 'mock_device.dart';

/// Build the hub backend from `--dart-define=HUB_MODE=...`.
///
/// Defaults to [MockDevice]. Serial requires desktop + `SERIAL_PORT`.
HubDevice createHubDeviceFromEnvironment() {
  const mode = String.fromEnvironment('HUB_MODE', defaultValue: 'mock');
  switch (mode.toLowerCase()) {
    case 'serial':
      return serial_factory.createSerialDeviceFromEnvironment();
    case 'mock':
    case '':
      return MockDevice();
    default:
      throw StateError(
        'Unknown HUB_MODE="$mode" (expected mock or serial)',
      );
  }
}
