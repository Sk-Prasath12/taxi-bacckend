import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

/// Compact bottom strip: vehicle info only. Today Summary lives on the Earnings tab.
class FigmaSummarySheet extends StatelessWidget {
  final String vehicleName;
  final String vehiclePlate;
  final String? vehicleTypeLabel;
  final bool isVerified;
  final VoidCallback? onOpenEarnings;

  const FigmaSummarySheet({
    super.key,
    this.vehicleName = 'Your vehicle',
    this.vehiclePlate = 'Add vehicle details',
    this.vehicleTypeLabel,
    this.isVerified = false,
    this.onOpenEarnings,
  });

  IconData get _vehicleIcon {
    final t = (vehicleTypeLabel ?? vehicleName).toLowerCase();
    if (t.contains('bike')) return Icons.two_wheeler_rounded;
    if (t.contains('auto')) return Icons.electric_rickshaw_rounded;
    if (t.contains('electric')) return Icons.electric_car_rounded;
    if (t.contains('accessible')) return Icons.accessible_rounded;
    if (t.contains('xl') || t.contains('van')) return Icons.airport_shuttle_outlined;
    if (t.contains('suv')) return Icons.airport_shuttle_rounded;
    return Icons.directions_car_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = vehiclePlate.isNotEmpty && vehiclePlate != '—'
        ? vehiclePlate
        : 'Add vehicle number in setup';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_vehicleIcon, color: AppColors.green, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vehicleTypeLabel?.isNotEmpty == true ? vehicleTypeLabel! : vehicleName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isVerified) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.green),
              ),
              child: const Text(
                'VERIFIED',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (onOpenEarnings != null)
            TextButton(
              onPressed: onOpenEarnings,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Earnings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
