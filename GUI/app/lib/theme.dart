import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Operator-console palette.
abstract final class HubColors {
  static const bg = Color(0xFF0A0E17);
  static const surface = Color(0xFF111827);
  static const surfaceRaised = Color(0xFF1A2234);
  static const border = Color(0xFF243044);
  static const text = Color(0xFFE2E8F0);
  static const muted = Color(0xFF94A3B8);
  static const accent = Color(0xFF38BDF8);
  static const ok = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
}

ThemeData buildHubTheme() {
  final textTheme = GoogleFonts.ibmPlexSansTextTheme(
    ThemeData(brightness: Brightness.dark).textTheme,
  ).apply(
    bodyColor: HubColors.text,
    displayColor: HubColors.text,
  );

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: HubColors.bg,
    colorScheme: const ColorScheme.dark(
      surface: HubColors.surface,
      primary: HubColors.accent,
      onPrimary: HubColors.bg,
      error: HubColors.danger,
    ),
    textTheme: textTheme,
    dividerColor: HubColors.border,
    useMaterial3: true,
  );
}
