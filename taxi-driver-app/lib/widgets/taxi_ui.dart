import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/fare_calculator.dart';

class TaxiGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const TaxiGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }
}

class TaxiPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const TaxiPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : AppColors.greenGradient,
          borderRadius: BorderRadius.circular(16),
          color: onPressed == null ? AppColors.offline : null,
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
        ),
      ),
    );
  }
}

class TaxiFareBreakdown extends StatelessWidget {
  final double distanceKm;
  final double durationMin;
  final double baseFare;
  final double? ratePerKm;
  final bool compact;

  const TaxiFareBreakdown({
    super.key,
    required this.distanceKm,
    required this.durationMin,
    this.baseFare = 0,
    this.ratePerKm,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = FareCalculator.breakdown(
      distanceKm: distanceKm,
      durationMin: durationMin,
      baseFare: baseFare,
      ratePerKm: ratePerKm,
    );

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, size: compact ? 18 : 22, color: AppColors.greenDark),
              const SizedBox(width: 8),
              Text(
                'Fare breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 14 : 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (baseFare > 0) _row('Base fare', baseFare),
          _row('Distance (${distanceKm.toStringAsFixed(1)} km × ₹${(ratePerKm ?? FareCalculator.perKm).toStringAsFixed(0)})', b['distance']!),
          _row(
            'Time (${b['billable_minutes']!.toStringAsFixed(0)} min × ₹${FareCalculator.perMin.toStringAsFixed(0)} · 1st min free)',
            b['time']!,
          ),
          const Divider(height: 20),
          _row('Total', b['total']!, bold: true, accent: true),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              'Cancellation fee: ₹${FareCalculator.cancellationFee.toStringAsFixed(0)} (paid to driver)',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {bool bold = false, bool accent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: accent ? AppColors.greenDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class TaxiStatusBadge extends StatelessWidget {
  final bool isOnline;

  const TaxiStatusBadge({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (isOnline ? AppColors.online : AppColors.offline).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isOnline ? AppColors.online : AppColors.offline).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? AppColors.online : AppColors.offline,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOnline ? 'ON DUTY' : 'OFF DUTY',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
              color: isOnline ? AppColors.online : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
