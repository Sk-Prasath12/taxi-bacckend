import 'package:flutter/material.dart';

/// Figma Taxi Driver App — dark theme: green buttons, yellow login accents.
abstract final class AppColors {
  // Backgrounds
  static const Color scaffoldDark = Color(0xFF12121B);
  static const Color cardDark = Color(0xFF1C1C23);
  static const Color cardDarkElevated = Color(0xFF252530);
  static const Color mapOverlay = Color(0xFF0F0F13);

  // Primary — all buttons & actions
  static const Color green = Color(0xFF34D399);
  static const Color greenDark = Color(0xFF10B981);
  static const Color greenLight = Color(0xFF064E3B);

  // OSRM map — distinct from green UI buttons
  static const Color mapRoute = Color(0xFF38BDF8);
  static const Color mapRouteDark = Color(0xFF0284C7);
  static const Color mapDriver = Color(0xFFFBBF24);

  // Login / brand yellow
  static const Color gold = Color(0xFFFBBF24);
  static const Color goldDark = Color(0xFFF59E0B);

  // Text on dark backgrounds
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textOnDark = textPrimary;

  // Light surfaces (white/grey cards, inputs)
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardLightMuted = Color(0xFFF3F4F6);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color textOnLight = Color(0xFF111827);
  static const Color textOnLightSecondary = Color(0xFF4B5563);
  static const Color textOnLightMuted = Color(0xFF6B7280);

  // Semantic
  static const Color online = green;
  static const Color offline = textMuted;
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = gold;
  static const Color success = green;

  // Legacy aliases
  static const Color black = scaffoldDark;
  static const Color blackLight = cardDark;
  static const Color blackCard = cardDark;
  static const Color surface = cardDark;
  static const Color card = cardDarkElevated;
  static const Color navy = scaffoldDark;
  static const Color navyLight = cardDark;
  static const Color actionRed = danger;
  static const Color actionRedDark = Color(0xFFDC2626);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [scaffoldDark, cardDark],
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [green, greenDark],
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldDark],
  );

  static const LinearGradient goOnlineGradient = greenGradient;

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: AppColors.textSecondary,
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static List<BoxShadow> goOnlineGlow = [
    BoxShadow(
      color: Color(0x6634D399),
      blurRadius: 32,
      spreadRadius: 4,
    ),
    BoxShadow(
      color: Color(0x3334D399),
      blurRadius: 48,
      spreadRadius: 8,
    ),
  ];

  static List<BoxShadow> goldGlow = [
    BoxShadow(
      color: Color(0x66FBBF24),
      blurRadius: 24,
      spreadRadius: 2,
    ),
  ];

  static BorderRadius get radiusLg => BorderRadius.circular(24);
  static BorderRadius get radiusMd => BorderRadius.circular(16);
  static BorderRadius get radiusSm => BorderRadius.circular(12);
}
