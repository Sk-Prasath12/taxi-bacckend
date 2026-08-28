import 'package:flutter/material.dart';

/// Figma design tokens — dark navy + blue accent taxi app.
class AppTheme {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color background = Color(0xFF1A1C24);
  static const Color surface = Color(0xFF23262F);
  static const Color surfaceLight = Color(0xFF2C303A);
  static const Color ink = Color(0xFF1A1C24);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color inkMuted = textSecondary;
  static const Color border = Color(0xFF3A3F4B);
  static const Color card = Color(0xFF23262F);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1C24), Color(0xFF1E3A8A)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
  );

  static BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? primary : border,
          width: selected ? 2 : 1,
        ),
      );

  static BoxDecoration sheetDecoration() => const BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      );

  static ThemeData materialTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: primary,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          surface: surface,
          onPrimary: onPrimary,
          onSurface: textPrimary,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: primary,
          circularTrackColor: Color(0x332563EB),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: textPrimary,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: background,
          selectedItemColor: primary,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: onPrimary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
}
