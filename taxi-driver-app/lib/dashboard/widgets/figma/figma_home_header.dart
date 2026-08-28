import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

/// Compact top bar for the Drive tab — no profile avatar (use bottom nav Profile).
class FigmaHomeHeader extends StatelessWidget {
  final String driverName;
  final String? vehicleLabel;
  final bool isOnDuty;
  final bool dutyLoading;
  final VoidCallback? onDutyToggle;
  final VoidCallback? onNotificationsTap;

  const FigmaHomeHeader({
    super.key,
    required this.driverName,
    this.vehicleLabel,
    required this.isOnDuty,
    this.dutyLoading = false,
    this.onDutyToggle,
    this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardDark.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.25)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (vehicleLabel != null && vehicleLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        vehicleLabel!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _DutyPill(
                isOnDuty: isOnDuty,
                loading: dutyLoading,
                onTap: onDutyToggle,
              ),
              if (onNotificationsTap != null) ...[
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 22),
                  onPressed: onNotificationsTap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DutyPill extends StatelessWidget {
  final bool isOnDuty;
  final bool loading;
  final VoidCallback? onTap;

  const _DutyPill({
    required this.isOnDuty,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnDuty ? AppColors.green : AppColors.textMuted;
    final label = isOnDuty ? 'ONLINE' : 'GO ONLINE';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.85), width: 1.5),
            color: color.withValues(alpha: 0.12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
