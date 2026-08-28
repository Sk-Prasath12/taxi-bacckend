import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taxiapp/core/app_colors.dart';

class AppTheme {
  /// Safe Inter style — never throws if font assets / network are unavailable.
  static TextStyle _inter({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
  }) {
    try {
      return _inter(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        fontFamily: 'sans-serif',
      );
    }
  }

  static TextTheme _interTextTheme(TextTheme base) {
    try {
      return GoogleFonts.interTextTheme(base).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );
    } catch (_) {
      return base.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamily: 'sans-serif',
      );
    }
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.green,
        onPrimary: Colors.white,
        secondary: AppColors.gold,
        onSecondary: AppColors.scaffoldDark,
        surface: AppColors.cardDark,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.scaffoldDark,
      canvasColor: AppColors.cardDark,
      dividerColor: AppColors.textMuted.withValues(alpha: 0.35),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    );

    final textTheme = _interTextTheme(base.textTheme);

    final inputText = _inter(
      color: AppColors.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );

    final themedText = textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(color: AppColors.textPrimary),
      displayMedium: textTheme.displayMedium?.copyWith(color: AppColors.textPrimary),
      displaySmall: textTheme.displaySmall?.copyWith(color: AppColors.textPrimary),
      headlineLarge: textTheme.headlineLarge?.copyWith(color: AppColors.textPrimary),
      headlineMedium: textTheme.headlineMedium?.copyWith(color: AppColors.textPrimary),
      headlineSmall: textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary),
      titleLarge: textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
      titleMedium: inputText,
      titleSmall: textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
      bodyLarge: inputText,
      bodyMedium: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
      bodySmall: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      labelLarge: textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
      labelMedium: textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
      labelSmall: textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
    );

    final greenButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: AppColors.green,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: AppColors.radiusMd),
      textStyle: _inter(fontSize: 16, fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      textTheme: themedText,
      primaryTextTheme: themedText,
      primaryColor: AppColors.green,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffoldDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: _inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppColors.radiusLg),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardDarkElevated,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _inter(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: _inter(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardDarkElevated,
        modalBackgroundColor: AppColors.cardDarkElevated,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.cardDarkElevated,
        textStyle: _inter(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: greenButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: greenButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.green,
          side: const BorderSide(color: AppColors.green),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: AppColors.radiusMd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: _inter(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.scaffoldDark,
        selectedItemColor: AppColors.green,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: _inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: _inter(fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDarkElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: AppColors.radiusMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppColors.radiusMd,
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppColors.radiusMd,
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
        labelStyle: _inter(color: AppColors.textSecondary),
        floatingLabelStyle: _inter(color: AppColors.green),
        hintStyle: _inter(color: AppColors.textMuted),
        prefixIconColor: AppColors.gold,
        suffixIconColor: AppColors.textSecondary,
        errorStyle: _inter(color: AppColors.danger, fontSize: 12),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.green,
        selectionColor: Color(0x5534D399),
        selectionHandleColor: AppColors.green,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardDarkElevated,
        contentTextStyle: _inter(color: AppColors.textPrimary),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.cardDark),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.green),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.green;
          return AppColors.textMuted;
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.green,
        textColor: AppColors.textPrimary,
        titleTextStyle: _inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        subtitleTextStyle: _inter(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardDarkElevated,
        labelStyle: _inter(color: AppColors.textPrimary),
        secondaryLabelStyle: _inter(color: AppColors.textSecondary),
        side: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.4)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.cardDarkElevated,
          borderRadius: AppColors.radiusSm,
        ),
        textStyle: _inter(color: AppColors.textPrimary, fontSize: 12),
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme;
}
