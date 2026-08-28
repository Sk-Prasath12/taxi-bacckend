import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';

/// Login backdrop — dark + yellow brand accent (no blue/red).
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffoldDark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.green.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.goldGlow,
                  ),
                  child: const Icon(TaxiIcons.taxi, color: AppColors.scaffoldDark, size: 36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
