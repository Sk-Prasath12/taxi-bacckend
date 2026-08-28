import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

/// Compact floating GO ONLINE / GO OFFLINE control.
class FigmaGoOnlineButton extends StatelessWidget {
  final bool isOnDuty;
  final VoidCallback onTap;
  final bool loading;
  final bool compact;

  const FigmaGoOnlineButton({
    super.key,
    required this.isOnDuty,
    required this.onTap,
    this.loading = false,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final label = isOnDuty ? 'Offline' : 'Online';
    final height = compact ? 36.0 : 44.0;
    final fontSize = compact ? 11.0 : 12.0;
    final iconSize = compact ? 16.0 : 18.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: isOnDuty ? null : AppColors.greenGradient,
            color: isOnDuty ? AppColors.cardDark.withValues(alpha: 0.96) : null,
            border: isOnDuty
                ? Border.all(color: AppColors.textMuted.withValues(alpha: 0.35))
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    color: isOnDuty ? AppColors.textPrimary : Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  isOnDuty ? Icons.pause_circle_outline_rounded : Icons.power_settings_new_rounded,
                  color: isOnDuty ? AppColors.textPrimary : AppColors.cardDark,
                  size: iconSize,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isOnDuty ? AppColors.textPrimary : AppColors.cardDark,
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
