import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class EarningsCard extends StatefulWidget {
  const EarningsCard({super.key});

  @override
  State<EarningsCard> createState() => _EarningsCardState();
}

class _EarningsCardState extends State<EarningsCard> {
  bool _showAmount = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showAmount = !_showAmount),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's earnings",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _showAmount ? '₹0' : 'Tap to reveal',
                      key: ValueKey(_showAmount),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _showAmount ? Icons.visibility_off_outlined : Icons.chevron_right_rounded,
              color: AppColors.navy,
            ),
          ],
        ),
      ),
    );
  }
}
