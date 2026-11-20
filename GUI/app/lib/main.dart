import 'package:flutter/material.dart';

import 'console_shell.dart';
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
      title: 'Peripheral Interface Security System',
      debugShowCheckedModeBanner: false,
      theme: buildHubTheme(),
      home: ConsoleShell(hub: hub),
    );
  }
}
