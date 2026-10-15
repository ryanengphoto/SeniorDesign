import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'hub_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final hub = HubService.fromEnvironment();
  runApp(HubConsoleApp(hub: hub));
}

class HubConsoleApp extends StatelessWidget {
  const HubConsoleApp({super.key, required this.hub});

  final HubService hub;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USB Hub Operator Console',
      debugShowCheckedModeBanner: false,
      theme: buildHubTheme(),
      home: DashboardPage(hub: hub),
    );
  }
}
