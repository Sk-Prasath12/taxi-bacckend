import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/services/osrm_service.dart';
import 'package:taxiapp/utils/ride_navigation_utils.dart';

/// Turn-by-turn banner (Google Maps style) for OSRM navigation.
class RideNavBanner extends StatelessWidget {
  final OsrmNavStep? step;
  final double distanceKm;
  final double etaMin;
  final String? subtitle;

  const RideNavBanner({
    super.key,
    this.step,
    required this.distanceKm,
    required this.etaMin,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final instruction = step?.instruction ?? 'Calculating route…';
    final icon = step?.icon ?? Icons.navigation;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDarkElevated,
        borderRadius: AppColors.radiusMd,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.green, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ??
                      '${RideNavigationUtils.formatDistance(distanceKm * 1000)} · '
                      '${RideNavigationUtils.formatEta(etaMin)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
