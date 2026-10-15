import 'package:flutter_test/flutter_test.dart';
import 'package:hub_console/serial_device.dart';

void main() {
  test('normalizePortPath keeps Linux paths and low COM numbers', () {
    expect(SerialDevice.normalizePortPath('/dev/ttyUSB1'), '/dev/ttyUSB1');
    expect(SerialDevice.normalizePortPath('/tmp/hub_host'), '/tmp/hub_host');
    expect(SerialDevice.normalizePortPath('COM3'), 'COM3');
    expect(SerialDevice.normalizePortPath('com4'), 'COM4');
  });

  test('normalizePortPath prefixes COM10+ for Win32', () {
    expect(SerialDevice.normalizePortPath('COM10'), r'\\.\COM10');
    expect(SerialDevice.normalizePortPath('com15'), r'\\.\COM15');
  });
}
