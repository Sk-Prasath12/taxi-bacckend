import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Standalone payment types screen, opened from the drawer "Payment" item.
/// Lets the user see and choose their preferred default payment method.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String _selectedMethod = 'Cash';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Payment preferences',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a default method. You can still change it during booking.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buildExpandableSection(
            method: 'Cash',
            title: 'Cash - Cash on delivery',
            icon: Icons.payments_outlined,
            content: _buildInfoRow(
              icon: Icons.payments_outlined,
              title: 'Cash on delivery',
              subtitle: 'Pay the driver in cash once the trip is completed.',
            ),
          ),
          const SizedBox(height: 12),
          _buildExpandableSection(
            method: 'Card',
            title: 'Card - Saved / new card',
            icon: Icons.credit_card,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: Icons.credit_card,
                  title: 'Saved cards',
                  subtitle: 'Use one of your saved cards or add a new one.',
                ),
                const SizedBox(height: 16),
                _buildSavedCardPreview(),
                const SizedBox(height: 20),
                _buildAddCardForm(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildExpandableSection(
            method: 'UPI',
            title: 'UPI - Google Pay / PhonePe / Paytm',
            icon: Icons.account_balance_wallet_outlined,
            content: _buildInfoRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'UPI',
              subtitle:
                  'Pay using your favourite UPI apps like GPay, PhonePe, Paytm.',
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      hintStyle: const TextStyle(color: AppTheme.textMuted),
      filled: true,
      fillColor: AppTheme.surfaceLight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedCardPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '••••  ••••  ••••  1234',
            style: TextStyle(
              color: AppTheme.onPrimary,
              fontSize: 18,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manimaran',
            style: TextStyle(color: AppTheme.onPrimary, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'VALID  12/28',
            style: TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add new card',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: _fieldDecoration(
            'Card number',
            hint: '1234 5678 9012 3456',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _fieldDecoration('CVV', hint: '123'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                keyboardType: TextInputType.datetime,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _fieldDecoration('Expiry date', hint: 'MM/YY'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandableSection({
    required String method,
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    final bool isOpen = _selectedMethod == method;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(80),
            side: BorderSide(
              color: isOpen ? AppTheme.primary : AppTheme.border,
              width: 2,
            ),
            backgroundColor: isOpen
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
          onPressed: () {
            setState(() {
              if (isOpen) {
                _selectedMethod = '';
              } else {
                _selectedMethod = method;
              }
            });
          },
          child: Row(
            children: [
              Icon(
                icon,
                color: isOpen ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(
                isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
        if (isOpen) ...[
          const SizedBox(height: 12),
          content,
        ],
      ],
    );
  }
}
