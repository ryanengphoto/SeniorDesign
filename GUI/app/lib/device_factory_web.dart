import 'hub_device.dart';

/// Web: serial is unsupported (no UART / libserialport).
HubDevice createSerialDeviceFromEnvironment() {
  throw UnsupportedError(
    'HUB_MODE=serial is not supported on Flutter web. '
    'Use `make linux-serial` (WSL/Linux) or '
    r'`.\scripts\run_windows_serial.ps1` (Windows COM).',
  );
}
