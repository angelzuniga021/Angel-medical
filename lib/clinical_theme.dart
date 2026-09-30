import 'package:flutter/material.dart';

import 'db.dart';

final clinicalThemeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
Future<void> loadClinicalTheme() async {
  final value = await AppDb.instance.getSetting('theme_mode');
  clinicalThemeMode.value = value == 'light'
      ? ThemeMode.light
      : value == 'system'
      ? ThemeMode.system
      : ThemeMode.dark;
}

ThemeData clinicalTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2376D8),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0A111C)
        : const Color(0xFFF2F6FB),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0F1C2D) : Colors.white,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF142236) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark ? const Color(0xFF25394E) : const Color(0xFFE0E8F2),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF101D2D) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
    ),
  );
}
