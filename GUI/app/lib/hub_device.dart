import 'dart:async';

import 'protocol.dart';

/// Shared backend for mock and serial hub transports.
///
/// Mock is poll-style ([isPolled] true + [getTelemetry]).
/// Serial is stream-style ([isPolled] false + [frames]).
abstract class HubDevice {
  /// Mode badge label, e.g. `mock`, `serial`, `serial_error`,
  /// `serial_reconnecting`.
  String get mode;

  /// Optional detail for the UI (serial port path).
  String? get detail => null;

  /// Last transport error, if any (serial only).
  String? get errorMessage => null;

  /// When true, the UI may offer Retry / the device auto-reconnects.
  bool get supportsReconnect => false;

  /// When true, [HubService] polls [getTelemetry] at 10 Hz.
  bool get isPolled;

  /// Elapsed ms since [start] (used for operator command events).
  int get elapsedMs;

  void start();

  /// Close and reopen the link (serial). No-op for mock.
  void reconnect() {}

  void dispose();

  /// Latest frame. Always valid after [start] for mock; may be null until
  /// the first UART line arrives for serial.
  TelemetryFrame? getTelemetry();

  /// Push frames when [isPolled] is false. Unused for mock.
  Stream<TelemetryFrame> get frames;

  /// Fires when [mode] / connection status changes without a new frame
  /// (e.g. serial open failure / reconnect). Default is never.
  Stream<void> get statusChanges => Stream<void>.empty();

  (PortState, int, String) isolatePort(int portId);

  (PortState, int, String) restorePort(int portId);

  (PortState, int, String)? clearFault(int portId);
}
