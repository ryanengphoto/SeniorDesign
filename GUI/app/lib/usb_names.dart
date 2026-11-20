/// USB vendor and product identifier lookup for human-readable device names.
abstract final class UsbNames {
  static String? _normalizeHex(String raw) {
    var s = raw.trim().toLowerCase();
    if (s.startsWith('0x')) {
      s = s.substring(2);
    }
    if (s.isEmpty) {
      return null;
    }
    // Pad to 4 hex chars if shorter (e.g. "46d" -> "046d")
    while (s.length < 4) {
      s = '0$s';
    }
    return s;
  }

  static bool isZeroOrEmpty(String? raw) {
    if (raw == null) return true;
    final norm = _normalizeHex(raw);
    return norm == null || norm == '0000';
  }

  /// Resolves human-readable name for a given VID/PID.
  /// Returns null if VID is 0000 or empty.
  /// Returns known product name, known vendor ("Vendor Device"), or "Unknown device".
  static String? lookup(String vidRaw, String pidRaw) {
    final vid = _normalizeHex(vidRaw);
    final pid = _normalizeHex(pidRaw);

    if (vid == null || vid == '0000') {
      return null;
    }

    // 1. Direct match on (VID:PID)
    if (pid != null && pid != '0000') {
      final key = '$vid:$pid';
      final product = _products[key];
      if (product != null) {
        return product;
      }
    }

    // 2. Fall back to Vendor name
    final vendor = _vendors[vid];
    if (vendor != null) {
      return '$vendor Device';
    }

    // 3. Fallback
    return 'Unknown device';
  }

  /// Decoded producer/vendor translation for VID (e.g. "Logitech").
  static String lookupVendor(String vidRaw) {
    final vid = _normalizeHex(vidRaw);
    if (vid == null || vid == '0000') {
      return '—';
    }
    return _vendors[vid] ?? 'Unknown vendor';
  }

  /// Decoded product model translation for PID (e.g. "K120 Keyboard").
  static String lookupProduct(String vidRaw, String pidRaw) {
    final vid = _normalizeHex(vidRaw);
    final pid = _normalizeHex(pidRaw);
    if (vid == null || vid == '0000' || pid == null || pid == '0000') {
      return '—';
    }
    final key = '$vid:$pid';
    final product = _products[key];
    if (product != null) {
      final vendor = _vendors[vid];
      if (vendor != null && product.startsWith('$vendor ')) {
        return product.substring(vendor.length + 1);
      }
      return product;
    }
    return 'Unknown model';
  }

  /// Decoded device class translation (bDeviceClass).
  static String lookupDeviceClass(String devClassRaw) {
    final norm = _normalizeHex(devClassRaw);
    if (norm == null) return '—';
    final val = int.tryParse(norm, radix: 16);
    if (val == null) return devClassRaw;
    return switch (val) {
      0x00 => 'Per-interface',
      0x02 => 'CDC Control',
      0x03 => 'HID',
      0x08 => 'Mass Storage',
      0x09 => 'USB Hub',
      0xEF => 'Miscellaneous',
      0xFF => 'Vendor-specific',
      _ => 'Class 0x$norm',
    };
  }

  /// Decoded interface class translation (bInterfaceClass).
  /// Explains what identifies a device type (e.g. 0x03 -> "HID (Keyboard)").
  static String lookupInterfaceClass(String intClassRaw) {
    final norm = _normalizeHex(intClassRaw);
    if (norm == null) return '—';
    final val = int.tryParse(norm, radix: 16);
    if (val == null) return intClassRaw;
    return switch (val) {
      0x00 => '—',
      0x01 => 'Audio',
      0x02 => 'CDC Control',
      0x03 => 'HID (Keyboard / Mouse)',
      0x06 => 'Image',
      0x07 => 'Printer',
      0x08 => 'Mass Storage',
      0x09 => 'USB Hub',
      0x0A => 'CDC Data',
      0x0E => 'Video (UVC)',
      0xE0 => 'Wireless',
      0xFF => 'Vendor-specific',
      _ => 'Class 0x$norm',
    };
  }

  static const Map<String, String> _vendors = {
    '046d': 'Logitech',
    '0781': 'SanDisk',
    '0483': 'STMicroelectronics',
    '10c4': 'Silicon Labs',
    '0403': 'FTDI',
    '1a86': 'WCH (QinHeng)',
    '067b': 'Prolific',
    '16c0': 'Van Ooijen / Teensy',
    '1209': 'Generic / Open Source',
    '1d50': 'OpenMoko',
    '045e': 'Microsoft',
    '05ac': 'Apple',
    '1b1c': 'Corsair',
    '1532': 'Razer',
    '1038': 'SteelSeries',
    '03f0': 'HP',
    '413c': 'Dell',
    '17ef': 'Lenovo',
    '0BDA': 'Realtek',
    '0951': 'Kingston',
    '18d1': 'Google',
    '1050': 'Yubico',
    '04d8': 'Microchip',
    '04b4': 'Cypress',
    '1443': 'Digilent',
    '2e8a': 'Raspberry Pi',
    '3434': 'Keychron',
    '1234': 'Demo Device',
  };

  static const Map<String, String> _products = {
    // Demonstration & self-stimulation
    '1234:5678': 'Demo Self-Stim Keyboard',

    // SanDisk
    '0781:5583': 'SanDisk Ultra Fit',
    '0781:5567': 'SanDisk Cruzer Blade',
    '0781:5581': 'SanDisk Ultra',
    '0781:5571': 'SanDisk Cruzer Fit',
    '0781:5591': 'SanDisk Ultra Flair',

    // Logitech
    '046d:c31c': 'Logitech K120 Keyboard',
    '046d:c31d': 'Logitech Media Keyboard K200',
    '046d:c326': 'Logitech K840 Mechanical Keyboard',
    '046d:c332': 'Logitech G213 Gaming Keyboard',
    '046d:c339': 'Logitech G Pro Gaming Keyboard',
    '046d:c077': 'Logitech M105 Optical Mouse',
    '046d:c016': 'Logitech Optical Wheel Mouse',
    '046d:c05a': 'Logitech M90 Optical Mouse',
    '046d:c084': 'Logitech G203 Gaming Mouse',
    '046d:c07d': 'Logitech G502 Gaming Mouse',
    '046d:c52b': 'Logitech Unifying Receiver',
    '046d:c534': 'Logitech Wireless Receiver',
    '046d:c539': 'Logitech Lightspeed Receiver',
    '046d:c542': 'Logitech Bolt Receiver',

    // STMicroelectronics
    '0483:df11': 'STM32 DFU Bootloader',
    '0483:5740': 'STM32 Virtual COM Port',
    '0483:374b': 'ST-LINK/V2.1',
    '0483:3748': 'ST-LINK/V2',

    // Silicon Labs
    '10c4:ea60': 'CP2102 USB to UART Bridge',
    '10c4:ea70': 'CP2105 Dual USB to UART Bridge',

    // FTDI
    '0403:6001': 'FTDI FT232R USB UART',
    '0403:6010': 'FTDI FT2232C/D/H Dual UART',
    '0403:6011': 'FTDI FT4232H Quad UART',
    '0403:6014': 'FTDI FT232H Hi-Speed UART',
    '0403:6015': 'FTDI FT230X Basic UART',

    // WCH
    '1a86:7523': 'CH340 USB-Serial',
    '1a86:5523': 'CH341 USB-Serial',

    // Raspberry Pi
    '2e8a:0003': 'Raspberry Pi Pico (CDC)',
    '2e8a:0005': 'Raspberry Pi Pico (MicroPython)',
    '2e8a:000a': 'Raspberry Pi Pico (HID)',

    // Digilent
    '1443:0007': 'Digilent USB Device (JTAG)',
    '1443:1003': 'Digilent JTAG-SMT2',

    // Yubico
    '1050:0407': 'YubiKey 5 Series',
    '1050:0116': 'YubiKey NEO OTP+CCID',
    '1050:0402': 'YubiKey 4/5 OTP+U2F',

    // Microsoft
    '045e:00db': 'Microsoft Natural Ergonomic Keyboard 4000',
    '045e:0752': 'Microsoft Wired Keyboard 400',
    '045e:00cb': 'Microsoft Basic Optical Mouse',
    '045e:028e': 'Microsoft Xbox 360 Controller',

    // Dell
    '413c:2107': 'Dell KB216 Wired Keyboard',
    '413c:2005': 'Dell QuietKey Keyboard',
    '413c:301a': 'Dell MS116 Optical Mouse',

    // HP
    '03f0:034a': 'HP Slim USB Keyboard',
    '03f0:0024': 'HP Standard USB Keyboard',

    // Lenovo
    '17ef:6019': 'Lenovo Preferred Pro Keyboard',
    '17ef:608d': 'Lenovo USB Optical Mouse',

    // Apple
    '05ac:024f': 'Apple Magic Keyboard',
    '05ac:0220': 'Apple Keyboard with Numeric Keypad',

    // Teensy & BadUSB / Pentest
    '16c0:0486': 'Teensy USB Keyboard/Mouse',
    '16c0:0482': 'Teensy RawHID',
    '16c0:0478': 'Teensy HalfKay Bootloader',
  };
}
