import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';

/// Consistent green loading indicator on dark background.
class TaxiLoader extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const TaxiLoader({
    super.key,
    this.size = 36,
    this.color = AppColors.green,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

/// Full-screen dark loading (session restore, auth, etc.).
class TaxiLoadingScreen extends StatelessWidget {
  final String message;
  final bool showLogo;

  const TaxiLoadingScreen({
    super.key,
    this.message = 'Loading…',
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showLogo) ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(TaxiIcons.taxi, color: AppColors.scaffoldDark, size: 32),
              ),
              const SizedBox(height: 28),
            ],
            const TaxiLoader(size: 40),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline dialog / overlay loading.
Widget taxiLoadingOverlay({String? message}) {
  return Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.cardDarkElevated,
        borderRadius: AppColors.radiusMd,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TaxiLoader(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          ],
        ],
      ),
    ),
  );
}
