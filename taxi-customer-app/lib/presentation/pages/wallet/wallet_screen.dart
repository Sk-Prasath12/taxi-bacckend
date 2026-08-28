import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/ride_service.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/ride_history_format.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  double _balance = 0.0;
  List<WalletTransaction> _transactions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _totalSpentFromRides = 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Try backend wallet API first
      final balance = await WalletService.getBalance();
      var txns = await WalletService.getTransactions();

      // Fallback: build transactions from ride history
      if (txns.isEmpty) {
        try {
          final rides = await RideService.getRideHistory();
          txns = await WalletService.buildFromRideHistory(rides);
        } catch (_) {}
      }

      final rideMaps = <Map<String, dynamic>>[];
      try {
        for (final r in await RideService.getRideHistory()) {
          if (r is Map) rideMaps.add(Map<String, dynamic>.from(r));
        }
      } catch (_) {}
      final rideSummary = RideHistoryFormat.overallSummary(rideMaps);

      final totalSpent = rideSummary.totalSpent > 0
          ? rideSummary.totalSpent
          : txns
              .where((t) => t.type == 'ride_payment' || t.type == 'debit')
              .fold<double>(0.0, (sum, t) => sum + t.amount);

      final totalRefunds = txns
          .where((t) => t.type == 'refund' || t.type == 'credit')
          .fold<double>(0.0, (sum, t) => sum + t.amount);

      if (!mounted) return;
      setState(() {
        _balance = balance > 0 ? balance : (totalRefunds - totalSpent);
        _totalSpentFromRides = totalSpent;
        _transactions = txns;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 20),
                      const Text('Transactions',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      if (_transactions.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('No transactions yet',
                                    style:
                                        TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._groupedTransactionWidgets(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDB813).withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Color(0xFFFDB813), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Wallet Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₹${_balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip(
                'Total Spent',
                '₹${_totalSpentFromRides.toStringAsFixed(0)}',
                Icons.trending_down,
                AppTheme.danger,
              ),
              const SizedBox(width: 12),
              _statChip(
                'Refunds',
                '₹${_transactions.where((t) => t.type == 'refund' || t.type == 'credit').fold<double>(0, (s, t) => s + t.amount).toStringAsFixed(0)}',
                Icons.trending_up,
                Colors.green.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 10)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupedTransactionWidgets() {
    final sorted = [..._transactions]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final buckets = <String, List<WalletTransaction>>{};
    for (final t in sorted) {
      final key = RideHistoryFormat.dayKey(t.createdAt);
      buckets.putIfAbsent(key, () => []).add(t);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    final widgets = <Widget>[];
    for (final key in keys) {
      final list = buckets[key]!;
      final day = DateTime(list.first.createdAt.year, list.first.createdAt.month, list.first.createdAt.day);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            RideHistoryFormat.formatDayHeader(day),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      );
      widgets.addAll(list.map(_buildTransactionTile));
    }
    return widgets;
  }

  Widget _buildTransactionTile(WalletTransaction txn) {
    final isDebit = txn.type == 'ride_payment' || txn.type == 'debit';
    final isRefund = txn.type == 'refund' || txn.type == 'credit';
    final icon = isRefund
        ? Icons.arrow_downward
        : isDebit
            ? Icons.arrow_upward
            : Icons.swap_horiz;
    final color = isRefund
        ? Colors.green
        : isDebit
            ? Colors.red
            : Colors.orange;
    final amountPrefix = isRefund ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description.isNotEmpty
                      ? txn.description
                      : _typeLabel(txn.type),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(txn.createdAt),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$amountPrefix₹${txn.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'ride_payment':
        return 'Ride Payment';
      case 'credit':
        return 'Credit';
      case 'debit':
        return 'Debit';
      case 'refund':
        return 'Refund';
      default:
        return 'Transaction';
    }
  }
}
