import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hub_console/hub_service.dart';
import 'package:hub_console/main.dart';

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
    expect(find.textContaining('Hardware-secure USB Hub'), findsOneWidget);
    expect(find.textContaining('PORT 1'), findsWidgets);
    expect(find.textContaining('MOCK'), findsOneWidget);

    // Cancel the 10 Hz telemetry timer before the test binding checks invariants.
    hub.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
