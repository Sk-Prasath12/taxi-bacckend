import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

/// Text/background pairs — dark surfaces use light text, light surfaces use dark text.
abstract final class AppContrast {
  static const Color lightSurface = AppColors.cardLight;
  static const Color lightSurfaceMuted = AppColors.cardLightMuted;

  static TextStyle titleOnDark({double size = 16, FontWeight weight = FontWeight.w600}) =>
      TextStyle(color: AppColors.textPrimary, fontSize: size, fontWeight: weight);

  static TextStyle bodyOnDark({double size = 14}) =>
      TextStyle(color: AppColors.textPrimary, fontSize: size);

  static TextStyle secondaryOnDark({double size = 13}) =>
      TextStyle(color: AppColors.textSecondary, fontSize: size);

  static TextStyle titleOnLight({double size = 16, FontWeight weight = FontWeight.w600}) =>
      TextStyle(color: AppColors.textOnLight, fontSize: size, fontWeight: weight);

  static TextStyle bodyOnLight({double size = 14}) =>
      TextStyle(color: AppColors.textOnLight, fontSize: size);

  static TextStyle secondaryOnLight({double size = 13}) =>
      TextStyle(color: AppColors.textOnLightSecondary, fontSize: size);

  static BoxDecoration darkCard({BorderRadius? radius}) => BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: radius ?? AppColors.radiusMd,
        boxShadow: AppColors.cardShadow,
      );

  static BoxDecoration lightCard({BorderRadius? radius}) => BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: radius ?? AppColors.radiusMd,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  /// Wraps [child] so default text/icons use dark colors on a light panel.
  static Widget lightPanel({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding,
      decoration: lightCard(),
      child: DefaultTextStyle(
        style: bodyOnLight(),
        child: IconTheme(
          data: const IconThemeData(color: AppColors.textOnLight),
          child: child,
        ),
      ),
    );
  }
}
