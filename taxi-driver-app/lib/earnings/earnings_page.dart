import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/history_page.dart';
import 'package:taxiapp/services/driver_earnings_service.dart';

class EarningsPage extends StatefulWidget {
  final int refreshNonce;

  const EarningsPage({super.key, this.refreshNonce = 0});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage>
    with SingleTickerProviderStateMixin {
  String _selectedPeriod = 'Today';
  AnimationController? _animationController;
  Animation<double>? _animation;
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _loadError;

  Map<String, dynamic> get _data =>
      _summary ??
      {
        'total': 0.0,
        'rides': 0,
        'hours': 0.0,
        'cash': 0.0,
        'card': 0.0,
        'digital': 0.0,
        'commission': 0.0,
        'net': 0.0,
        'commission_percent': 15,
        'period_label': null,
        'daily_breakdown': <Map<String, dynamic>>[],
        'rides_list': <Map<String, dynamic>>[],
      };

  @override
  void didUpdateWidget(covariant EarningsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshNonce != oldWidget.refreshNonce) {
      _loadSummary();
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );
    _animationController!.forward();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final summary =
          await DriverEarningsService.instance.fetchSummary(_selectedPeriod);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
      _animationController?.reset();
      _animationController?.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Earnings'),
            if (_data['period_label'] != null)
              Text(
                '${_selectedPeriod} · ${_data['period_label']}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          // Period selector dropdown
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadSummary();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Today', child: Text('Today')),
              const PopupMenuItem(value: 'Weekly', child: Text('This Week')),
              const PopupMenuItem(value: 'Monthly', child: Text('This Month')),
              const PopupMenuItem(value: 'Yearly', child: Text('This Year')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(
                    _selectedPeriod,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading)
                const LinearProgressIndicator(minHeight: 2),
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not load earnings. Pull to refresh.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              _buildTotalEarningsCard(data),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(data),
                    const SizedBox(height: 24),
                    _buildPaymentBreakdown(data),
                    const SizedBox(height: 24),
                    _buildCommissionCard(data),
                    const SizedBox(height: 24),
                    _buildDailyBreakdown(data),
                    const SizedBox(height: 24),
                    _buildRecentEarningsList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalEarningsCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Earnings',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          FadeTransition(
            opacity: _animation!,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '₹${data['total'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                icon: Icons.directions_car,
                label: '${data['rides']} rides',
              ),
              _buildChip(
                icon: Icons.access_time,
                label: '${data['hours']}h online',
              ),
              _buildChip(
                icon: Icons.payments,
                label: 'Net ₹${(data['net'] as num).toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> data) {
    final width = MediaQuery.sizeOf(context).width;
    final aspect = width < 380 ? 1.35 : 1.45;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: aspect,
      children: [
        _buildStatCard(
          icon: Icons.money,
          title: 'Cash',
          value: '₹${data['cash'].toStringAsFixed(2)}',
          color: Colors.green,
        ),
        _buildStatCard(
          icon: Icons.credit_card,
          title: 'Card',
          value: '₹${data['card'].toStringAsFixed(2)}',
          color: AppColors.green,
        ),
        _buildStatCard(
          icon: Icons.phone_android,
          title: 'Digital',
          value: '₹${data['digital'].toStringAsFixed(2)}',
          color: AppColors.blackLight,
        ),
        _buildStatCard(
          icon: Icons.account_balance_wallet,
          title: 'Net',
          value: '₹${data['net'].toStringAsFixed(2)}',
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Methods',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildPaymentMethodItem(
            icon: Icons.money,
            method: 'Cash',
            amount: data['cash'] as double,
            total: data['total'] as double,
            color: Colors.green,
          ),
          const Divider(height: 24),
          _buildPaymentMethodItem(
            icon: Icons.credit_card,
            method: 'Credit Card',
            amount: data['card'] as double,
            total: data['total'] as double,
            color: AppColors.green,
          ),
          const Divider(height: 24),
          _buildPaymentMethodItem(
            icon: Icons.phone_android,
            method: 'Digital Wallet',
            amount: data['digital'] as double,
            total: data['total'] as double,
            color: AppColors.blackLight,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodItem({
    required IconData icon,
    required String method,
    required double amount,
    required double total,
    required Color color,
  }) {
    final percentage = total > 0 ? (amount / total * 100) : 0.0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                method,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommissionCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commission & Fees',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Commission',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${data['commission'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Earnings',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${data['net'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Commission rate: ${data['commission_percent'] ?? 15}% per ride (from completed fares)',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBreakdown(Map<String, dynamic> data) {
    final raw = data['daily_breakdown'];
    final days = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    if (days.isEmpty) return const SizedBox.shrink();
    if (days.length == 1 && _selectedPeriod == 'Today') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...days.map((day) {
          final date = day['date']?.toString() ?? '—';
          final rides = (day['rides'] as num?)?.toInt() ?? 0;
          final total = (day['total'] as num?)?.toDouble() ?? 0;
          final net = (day['net'] as num?)?.toDouble() ?? 0;
          final cash = (day['cash'] as num?)?.toDouble() ?? 0;
          final digital = (day['digital'] as num?)?.toDouble() ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$rides rides',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Fare ₹${total.toStringAsFixed(2)} · You earn ₹${net.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cash ₹${cash.toStringAsFixed(0)} · Online/UPI ₹${digital.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentEarningsList() {
    final raw = _data['rides_list'];
    final recentRides = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Rides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentRides.isEmpty && !_loading)
          Text(
            'No completed rides in this period.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ...recentRides.take(10).map(_buildRideListItemFromApi),
      ],
    );
  }

  Widget _buildRideListItemFromApi(Map<String, dynamic> ride) {
    final completed = DateTime.tryParse(ride['completed_at']?.toString() ?? '');
    final timeStr = completed != null
        ? DateFormat('MMM d, h:mm a').format(completed.toLocal())
        : '—';
    final pickup = ride['pickup']?.toString() ?? 'Pickup';
    final drop = ride['dropoff']?.toString() ?? 'Drop';
    final amount = (ride['driver_earnings'] as num?)?.toDouble() ??
        (ride['fare'] as num?)?.toDouble() ??
        0.0;
    final payment =
        ride['payment_label']?.toString() ?? ride['payment_bucket']?.toString() ?? 'Cash';
    final customer = ride['customer_name']?.toString();
    return _buildRideListItem({
      'time': timeStr,
      'pickup': pickup,
      'drop': drop,
      'amount': amount,
      'payment': payment,
      if (customer != null && customer.isNotEmpty) 'customer': customer,
    });
  }

  Widget _buildRideListItem(Map<String, dynamic> ride) {
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
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car,
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
                  '${ride['pickup']} → ${ride['drop']}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (ride['customer'] != null)
                  Text(
                    ride['customer'] as String,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                Text(
                  ride['time'] as String,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+₹${(ride['amount'] as num).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                _getPaymentIcon(ride['payment'] as String),
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String payment) {
    final p = payment.toLowerCase();
    if (p.contains('cash')) return Icons.money;
    if (p.contains('card')) return Icons.credit_card;
    return Icons.phone_android;
  }
}
