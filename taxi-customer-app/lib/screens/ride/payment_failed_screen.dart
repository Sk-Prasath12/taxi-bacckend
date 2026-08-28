import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shown when Razorpay payment fails or is cancelled.
class PaymentFailedScreen extends StatelessWidget {
  const PaymentFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final rideId = args?['rideId']?.toString() ?? '';
    final amount = args?['amount']?.toString() ?? '0';
    final method = args?['paymentMethod']?.toString() ?? 'Razorpay';
    final error = args?['errorMessage']?.toString() ?? 'Payment was not completed.';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  method,
                  style: const TextStyle(
                    color: AppTheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.cancel, color: AppTheme.danger, size: 96),
              const SizedBox(height: 20),
              const Text(
                'Payment Failed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'Status: FAILED',
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '₹$amount',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              if (rideId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Ride: $rideId',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/ride-payment',
                      arguments: {'rideId': rideId},
                    );
                  },
                  child: const Text('TRY AGAIN WITH RAZORPAY'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Back',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
