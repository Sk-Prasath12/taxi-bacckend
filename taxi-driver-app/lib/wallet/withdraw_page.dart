import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _selectedMethod = 'bank';
  
  final double _availableBalance = 1247.85;
  final double _minWithdraw = 10.00;
  final double _maxWithdraw = 1000.00;
  
  final List<Map<String, dynamic>> _withdrawHistory = [
    {
      'id': 1,
      'amount': 200.00,
      'method': 'Bank Transfer',
      'status': 'completed',
      'date': 'Mar 8, 2026',
      'time': '2-3 business days',
    },
    {
      'id': 2,
      'amount': 150.00,
      'method': 'PayPal',
      'status': 'pending',
      'date': 'Mar 10, 2026',
      'time': 'Instant',
    },
    {
      'id': 3,
      'amount': 300.00,
      'method': 'Bank Transfer',
      'status': 'processing',
      'date': 'Mar 9, 2026',
      'time': '1-2 business days',
    },
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Info
            _buildBalanceInfo(),
            const SizedBox(height: 24),

            // Withdraw Form
            _buildWithdrawForm(),
            const SizedBox(height: 32),

            // Withdraw History
            _buildWithdrawHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_availableBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.cardDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildLimitChip(
                  icon: Icons.arrow_downward,
                  label: 'Min',
                  value: '₹${_minWithdraw.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLimitChip(
                  icon: Icons.arrow_upward,
                  label: 'Max',
                  value: '₹${_maxWithdraw.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Withdrawal Amount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Amount Input
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.green,
              ),
              hintText: 'Enter amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.cardDarkElevated,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              final amount = double.tryParse(value);
              if (amount == null) {
                return 'Invalid amount';
              }
              if (amount < _minWithdraw) {
                return 'Minimum withdrawal is ₹${_minWithdraw.toStringAsFixed(2)}';
              }
              if (amount > _maxWithdraw) {
                return 'Maximum withdrawal is ₹${_maxWithdraw.toStringAsFixed(2)}';
              }
              if (amount > _availableBalance) {
                return 'Insufficient balance';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Payment Method Selection
          const Text(
            'Withdrawal Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildPaymentMethodOption(
            value: 'bank',
            icon: Icons.account_balance,
            title: 'Bank Transfer',
            subtitle: '2-3 business days',
            fee: 'Free',
          ),
          
          const SizedBox(height: 12),
          
          _buildPaymentMethodOption(
            value: 'paypal',
            icon: Icons.payment,
            title: 'PayPal',
            subtitle: 'Instant',
            fee: '2.5% fee',
          ),
          
          const SizedBox(height: 12),
          
          _buildPaymentMethodOption(
            value: 'card',
            icon: Icons.credit_card,
            title: 'Debit Card',
            subtitle: '1-2 business days',
            fee: '1% fee',
          ),
          
          const SizedBox(height: 32),
          
          // Quick Amount Buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickAmountButton(50),
              _buildQuickAmountButton(100),
              _buildQuickAmountButton(200),
              _buildQuickAmountButton(500),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Withdraw Now',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required String fee,
  }) {
    final isSelected = _selectedMethod == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    fee,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Radio<String>(
                  value: value,
                  groupValue: _selectedMethod,
                  onChanged: (value) {
                    setState(() {
                      _selectedMethod = value!;
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(double amount) {
    return Material(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(10),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          _amountController.text = amount.toStringAsFixed(2);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.green,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Withdrawal History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Viewing full history')),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        ..._withdrawHistory.map((withdrawal) => 
          _buildWithdrawHistoryItem(withdrawal),
        ),
      ],
    );
  }

  Widget _buildWithdrawHistoryItem(Map<String, dynamic> withdrawal) {
    Color statusColor;
    IconData statusIcon;
    
    switch (withdrawal['status']) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
        break;
      case 'processing':
        statusColor = AppColors.green;
        statusIcon = Icons.autorenew;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: AppColors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  withdrawal['method'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${withdrawal['date']} • ${withdrawal['time']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-?${(withdrawal['amount'] as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    (withdrawal['status'] as String).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleWithdraw() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Withdrawal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount: ₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Method: $_selectedMethod',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Processing fee will be applied',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Withdrawal of ₹${amount.toStringAsFixed(2)} submitted successfully!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                _amountController.clear();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    }
  }
}
