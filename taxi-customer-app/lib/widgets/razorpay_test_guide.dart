import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Razorpay test-mode credentials for QA (test keys only).
class RazorpayTestGuide extends StatelessWidget {
  const RazorpayTestGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Razorpay test mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _testRow('Success (UPI)', 'success@razorpay', AppTheme.success),
          _testRow('Failure (UPI)', 'failure@razorpay', AppTheme.danger),
          _testRow('Success (Card)', '4111 1111 1111 1111', AppTheme.success),
          const SizedBox(height: 6),
          const Text(
            'Any future expiry · any CVV · cancel checkout = FAILED',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _testRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            color == AppTheme.success
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
