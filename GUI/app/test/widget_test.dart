import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hub_console/dashboard_page.dart';
import 'package:hub_console/hub_service.dart';
import 'package:hub_console/main.dart';
import 'package:hub_console/protocol.dart';
import 'package:hub_console/theme.dart';
import 'package:hub_console/widgets/connection_banner.dart';
import 'package:hub_console/widgets/event_log.dart';
import 'package:hub_console/widgets/keyboard_confirm_dialog.dart';
import 'package:hub_console/widgets/port_card.dart';

import 'support/memory_event_log.dart';

void main() {
  setUpAll(() {
    // Avoid network font fetches hanging the widget test binding.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('dashboard shows operator console chrome', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final hub = HubService(eventLog: memoryEventLogStore());

    await tester.pumpWidget(HubConsoleApp(hub: hub));
    // Do not pumpAndSettle — mock telemetry Timer.periodic never goes idle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('OPERATOR CONSOLE'), findsOneWidget);
    expect(
      find.textContaining('Peripheral Interface Security System'),
      findsOneWidget,
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Database'), findsOneWidget);
    expect(find.textContaining('PORT 1'), findsWidgets);
    expect(find.textContaining('MOCK'), findsOneWidget);

    // Port cards should only have Isolate and Restore buttons —
    // Confirm keyboard button must NOT be taking up space in the port card.
    expect(find.widgetWithText(OutlinedButton, 'Confirm keyboard'), findsNothing);

    // Cancel the 10 Hz telemetry timer before the test binding checks invariants.
    hub.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('port card does not have Confirm keyboard action button when pending confirm',
      (tester) async {
    const pendingPort = PortStatus(
      port: 1,
      state: PortState.pendingHidConfirm,
      threatCode: 0,
      vid: '0x046D',
      pid: '0xC31C',
      devClass: '0x00',
      intClass: '0x03',
    );

    var requestedConfirm = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: PortCard(
            port: pendingPort,
            onCommand: (_, _) {},
            onRequestConfirmKeyboard: () {
              requestedConfirm = true;
            },
          ),
        ),
      ),
    );

    // Verify there is NO action button for Confirm keyboard in the actions row
    expect(find.widgetWithText(OutlinedButton, 'Confirm keyboard'), findsNothing);

    // Verify standard action buttons: Isolate and Restore are present, Clear fault is consolidated
    expect(find.widgetWithText(OutlinedButton, 'Isolate'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Restore'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Clear fault'), findsNothing);

    // Verify the identity section displays the pending confirm reason with interactive prompt
    expect(find.text('Confirm keyboard?'), findsOneWidget);

    // Verify resolved device name is displayed under port header
    expect(find.text('Logitech K120 Keyboard'), findsOneWidget);

    // Verify metrics show 4 key values on the same line with labels, hex, and decoded translations
    expect(find.text('VENDOR ID'), findsOneWidget);
    expect(find.text('0x046D'), findsOneWidget);
    expect(find.text('Logitech'), findsOneWidget);

    expect(find.text('PRODUCT ID'), findsOneWidget);
    expect(find.text('0xC31C'), findsOneWidget);
    expect(find.text('K120 Keyboard'), findsOneWidget);

    expect(find.text('DEVICE CLASS'), findsOneWidget);
    expect(find.text('0x00'), findsOneWidget);
    expect(find.text('Per-interface'), findsOneWidget);

    expect(find.text('INTERFACE CLASS'), findsOneWidget);
    expect(find.text('0x03'), findsOneWidget);
    expect(find.text('HID (Keyboard / Mouse)'), findsOneWidget);

    // Tapping the reason prompt requests keyboard confirmation
    await tester.tap(find.text('Confirm keyboard?'));
    await tester.pump();
    expect(requestedConfirm, isTrue);
  });

  testWidgets('KeyboardConfirmDialog displays device information and handles confirm/isolate',
      (tester) async {
    const pendingPort = PortStatus(
      port: 1,
      state: PortState.pendingHidConfirm,
      threatCode: 0,
      vid: '0x046D',
      pid: '0xC31C',
      devClass: '0x00',
      intClass: '0x03',
    );

    var confirmed = false;
    var isolated = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  KeyboardConfirmDialog.show(
                    context,
                    port: pendingPort,
                    onConfirm: () {
                      confirmed = true;
                    },
                    onIsolate: () {
                      isolated = true;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open the popup dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify popup content
    expect(find.text('Keyboard Detected'), findsOneWidget);
    expect(find.textContaining('PENDING AUTHORIZATION'), findsOneWidget);
    expect(find.textContaining('0x046D'), findsOneWidget);
    expect(find.textContaining('0xC31C'), findsOneWidget);
    expect(find.textContaining('0x03 HID'), findsOneWidget);
    expect(find.text('Dismiss'), findsNothing);
    expect(find.text('Isolate port'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Confirm keyboard'), findsOneWidget);

    // Tap confirm keyboard button in the popup
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm keyboard'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(isolated, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('port card displays unknown device when VID/PID is unmapped',
      (tester) async {
    const unknownPort = PortStatus(
      port: 0,
      state: PortState.authorized,
      threatCode: 0,
      vid: '0x9999',
      pid: '0x8888',
      devClass: '0x00',
      intClass: '0x00',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: PortCard(
            port: unknownPort,
            onCommand: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('PORT 1'), findsOneWidget);
    expect(find.text('Unknown device'), findsOneWidget);
  });

  testWidgets('port card does not show device name when disconnected with 0x0000',
      (tester) async {
    const idlePort = PortStatus(
      port: 2,
      state: PortState.disconnected,
      threatCode: 0,
      vid: '0x0000',
      pid: '0x0000',
      devClass: '0x00',
      intClass: '0x00',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: PortCard(
            port: idlePort,
            onCommand: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('PORT 3'), findsOneWidget);
    expect(find.text('Unknown device'), findsNothing);
  });

  testWidgets('dashboard page toggles sidebar log visibility', (tester) async {
    final hub = HubService(eventLog: memoryEventLogStore());

    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: DashboardPage(
            hub: hub,
            telemetry: null,
            events: const [],
          ),
        ),
      ),
    );

    // Initial state: log panel is visible and toggle button says "Hide log"
    expect(find.text('Hide log'), findsOneWidget);
    expect(find.text('Security event log'), findsOneWidget);

    // Click "Hide log"
    await tester.tap(find.text('Hide log'));
    await tester.pump();

    // Log panel is hidden, button says "Show log"
    expect(find.text('Hide log'), findsNothing);
    expect(find.text('Show log'), findsOneWidget);
    expect(find.text('Security event log'), findsNothing);

    // Click "Show log"
    await tester.tap(find.text('Show log'));
    await tester.pump();

    // Log panel is restored
    expect(find.text('Hide log'), findsOneWidget);
    expect(find.text('Security event log'), findsOneWidget);

    hub.dispose();
  });

  testWidgets('connection banner shows Disconnected when no port is picked',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: ConnectionBanner(
            connected: false,
            mode: 'serial',
            detail: null,
            supportsPortSelect: true,
            availablePorts: const ['COM3', 'COM4'],
            onPortSelected: (_) {},
            supportsBaudSelect: true,
            baudRate: 115200,
            onBaudSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Select COM'), findsOneWidget);
    expect(find.text('Baud rate'), findsOneWidget);
    expect(find.text('No port selected'), findsNothing);
    expect(find.text('Waiting…'), findsNothing);
  });

  testWidgets(
      'connection banner shows dynamic port disconnected without hardcoding',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: ConnectionBanner(
            connected: false,
            mode: 'serial_error',
            detail: 'COM7',
            supportsReconnect: true,
            onReconnect: () {},
            supportsPortSelect: true,
            availablePorts: const ['COM3', 'COM7'],
            onPortSelected: (_) {},
            supportsBaudSelect: true,
            baudRate: 115200,
            onBaudSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('COM7 disconnected'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('115200'), findsOneWidget);
    expect(find.text('SERIAL'), findsNothing);
  });

  testWidgets('connection banner shows Connected without SERIAL badge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: ConnectionBanner(
            connected: true,
            mode: 'serial',
            detail: 'COM3',
            supportsPortSelect: true,
            availablePorts: const ['COM3', 'COM4'],
            onPortSelected: (_) {},
            supportsBaudSelect: true,
            baudRate: 115200,
            onBaudSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('COM3'), findsWidgets);
    expect(find.text('Baud rate'), findsOneWidget);
    expect(find.text('115200'), findsOneWidget);
    expect(find.text('SERIAL'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('connection banner shows Reconnecting with Retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: ConnectionBanner(
            connected: false,
            mode: 'serial_reconnecting',
            detail: 'COM4',
            supportsReconnect: true,
            onReconnect: () {
              retried = true;
            },
            supportsPortSelect: true,
            availablePorts: const ['COM4'],
            onPortSelected: (_) {},
            supportsBaudSelect: true,
            baudRate: 57600,
            onBaudSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Reconnecting…'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('57600'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('connection banner mock mode has no COM/baud pickers',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: ConnectionBanner(
            connected: true,
            mode: 'mock',
            detail: null,
          ),
        ),
      ),
    );

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Select COM'), findsNothing);
    expect(find.text('Baud rate'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
      'sidebar event log shows newest events first and limits to 50 with show more',
      (tester) async {
    final now = DateTime.now();
    // Generate 60 events. Event 59 is newest.
    final events = List.generate(
      60,
      (i) => SecurityEvent(
        id: i + 1,
        at: now.add(Duration(seconds: i)),
        port: 0,
        threatCode: ThreatCode.noFault.value,
        threatName: ThreatCode.nameFor(ThreatCode.noFault.value),
        state: PortState.authorized,
        message: 'Event #$i',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildHubTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: EventLogPanel(
              events: events,
              onClearAll: () async {},
              onDeleteEvent: (_) async {},
            ),
          ),
        ),
      ),
    );

    // Header reflects pagination
    expect(find.text('Showing 50 of 60 events'), findsOneWidget);

    // Newest event (Event #59) is at top and visible
    expect(find.text('Event #59'), findsOneWidget);

    // Event #0 (oldest) should not be loaded yet
    expect(find.text('Event #0'), findsNothing);

    // "Show more (10 remaining)" button is present
    expect(find.text('Show more (10 remaining)'), findsOneWidget);

    // Tap "Show more"
    await tester.tap(find.text('Show more (10 remaining)'));
    await tester.pump();

    // Now all 60 events are visible and button is gone
    expect(find.text('60 events'), findsOneWidget);
    expect(find.textContaining('Show more'), findsNothing);
  });
}
