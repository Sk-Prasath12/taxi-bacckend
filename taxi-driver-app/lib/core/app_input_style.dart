import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

/// Typed text inside dark input fields.
abstract final class AppInputStyle {
  static const TextStyle field = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle fieldOnLight = TextStyle(
    color: AppColors.textOnLight,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );
}
