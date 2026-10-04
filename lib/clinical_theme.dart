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
    seedColor: const Color(0xFF3B8AE8),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF09131F)
        : const Color(0xFFF4F7FC),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0F1C2D) : Colors.white,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 21, fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: dark ? const Color(0xFF0E1D2C) : Colors.white,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    listTileTheme: const ListTileThemeData(horizontalTitleGap: 14),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 24),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF122234) : Colors.white,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
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
