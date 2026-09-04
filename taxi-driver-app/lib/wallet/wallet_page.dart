import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double _walletBalance = 0;
  double _totalEarned = 0;
  double _pendingAmount = 0;
  Future<Map<String, dynamic>?>? _walletFuture;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _walletFuture = _loadWallet();
  }

  Future<Map<String, dynamic>?> _loadWallet() async {
    final token = AuthService().token;
    if (token == null) {
      return null;
    }

    final wallet = await DriverApi.withToken(token).getWallet();
    if (wallet != null) {
      final data = wallet['data'] is Map ? Map<String, dynamic>.from(wallet['data'] as Map) : wallet;
      final txRaw = data['transactions'];
      final mapped = <Map<String, dynamic>>[];
      if (txRaw is List) {
        for (final item in txRaw) {
          if (item is! Map) continue;
          final t = Map<String, dynamic>.from(item);
          mapped.add(_mapWalletTransaction(t));
        }
      }
      if (mounted) {
        setState(() {
          _walletBalance = (data['balance'] as num?)?.toDouble() ?? 0;
          _totalEarned = (data['total_earned'] as num?)?.toDouble() ?? 0;
          _pendingAmount = (data['pending'] as num?)?.toDouble() ??
              (data['pending_amount'] as num?)?.toDouble() ??
              0;
          _transactions = mapped;
        });
      }
    }
    return wallet;
  }

  Map<String, dynamic> _mapWalletTransaction(Map<String, dynamic> t) {
    final amount = (t['amount'] as num?)?.toDouble() ?? 0;
    final method = (t['method'] ?? t['payment_mode'] ?? 'ONLINE').toString();
    final dt = DateTime.tryParse(t['date']?.toString() ?? t['createdAt']?.toString() ?? '');
    final dateStr = dt != null
        ? DateFormat('MMM d, y • h:mm a').format(dt.toLocal())
        : '—';
    final label = _paymentMethodLabel(method);
    final rideId = (t['rideId'] ?? t['ride_id'] ?? '').toString();
    final customerObj = t['customer'];
    final customer = customerObj is Map
        ? customerObj['name']?.toString()
        : t['customer_name']?.toString();
    final pickup = t['pickup'] is Map ? (t['pickup'] as Map)['address']?.toString() : null;
    final drop = t['drop'] is Map ? (t['drop'] as Map)['address']?.toString() : null;
    final fare = (t['fare'] as num?)?.toDouble();
    final vehicle = t['vehicle_type']?.toString();
    final paymentStatus = t['payment_status']?.toString() ?? 'SUCCESS';
    final parts = <String>[
      if (rideId.isNotEmpty) 'Ride #$rideId',
      if (customer != null && customer.isNotEmpty) customer,
      if (vehicle != null && vehicle.isNotEmpty) vehicle,
      if (pickup != null && pickup.isNotEmpty) pickup,
      if (drop != null && drop.isNotEmpty) '→ $drop',
      if (fare != null) 'Fare ₹${fare.toStringAsFixed(0)}',
      '$label · $paymentStatus',
    ];
    return {
      'id': t['id'] ?? rideId ?? dateStr,
      'type': amount >= 0 ? 'credit' : 'debit',
      'title': amount >= 0 ? 'Ride earnings' : 'Withdrawal',
      'description': parts.where((e) => e.trim().isNotEmpty).join(' · '),
      'amount': amount,
      'date': dateStr,
      'rideId': rideId,
      'fare': fare,
      'payment_status': paymentStatus,
      'icon': Icons.account_balance_wallet,
      'color': Colors.green,
    };
  }

  String _paymentMethodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return 'Cash';
      case 'RAZORPAY':
        return 'Online / UPI';
      case 'ONLINE':
        return 'Online';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          // Withdraw button in app bar
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () {
              Navigator.pushNamed(context, '/withdraw');
            },
            tooltip: 'Withdraw',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _walletFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final walletBalance = _walletBalance;
          final pendingAmount = _pendingAmount;
          final transactions = _transactions;

          return RefreshIndicator(
            onRefresh: () async {
              _walletFuture = _loadWallet();
              setState(() {});
              await _walletFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWalletCard(balance: walletBalance, pending: pendingAmount),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Viewing all transactions')),
                          );
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...transactions
                      .map((transaction) => _buildTransactionItem(transaction))
                      ,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWalletCard({required double balance, required double pending}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: AppColors.cardDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total earned ₹${_totalEarned.toStringAsFixed(2)} (cash + online)',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildBalanceInfo(
                  icon: Icons.pending_actions,
                  label: 'Commission due',
                  value: '₹${pending.toStringAsFixed(2)}',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildBalanceInfo(
                  icon: Icons.shield,
                  label: 'Secure',
                  value: 'Insured',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/withdraw');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardLight,
              foregroundColor: AppColors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Withdraw Funds',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.cardDark,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _buildQuickActionItem(
          icon: Icons.add,
          label: 'Add Money',
          color: Colors.green,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add money feature coming soon')),
            );
          },
        ),
        _buildQuickActionItem(
          icon: Icons.account_balance_wallet,
          label: 'Withdraw',
          color: AppColors.green,
          onTap: () {
            Navigator.pushNamed(context, '/withdraw');
          },
        ),
        _buildQuickActionItem(
          icon: Icons.history,
          label: 'History',
          color: AppColors.blackLight,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Viewing transaction history')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final bool isCredit = transaction['type'] == 'credit';
    
    return Dismissible(
      key: Key(transaction['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.red,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text(
              'Are you sure you want to delete this transaction?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        setState(() {
          _transactions.removeWhere(
            (t) => t['id'] == transaction['id'],
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      },
      child: Container(
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
                color: (transaction['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                transaction['icon'] as IconData,
                color: transaction['color'] as Color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction['title'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction['description'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction['date'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : ''}₹${transaction['amount'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCredit
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCredit ? 'Received' : 'Paid',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCredit ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
