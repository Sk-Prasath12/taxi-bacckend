import 'package:flutter/material.dart';

import '../../../services/ride_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/ride_history_format.dart';

class SpendDetailScreen extends StatefulWidget {
  const SpendDetailScreen({super.key});

  @override
  State<SpendDetailScreen> createState() => _SpendDetailScreenState();
}

class _SpendDetailScreenState extends State<SpendDetailScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await RideService.getRideHistory();
      final orders = <Map<String, dynamic>>[];
      for (final ride in raw) {
        if (ride is Map) orders.add(Map<String, dynamic>.from(ride));
      }
      if (!mounted) return;
      setState(() {
        _orders = orders;
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
    final summary = RideHistoryFormat.overallSummary(_orders);
    final groups = RideHistoryFormat.groupByDay(_orders);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Spending', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildSummaryHeader(summary),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: _load,
                        child: groups.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 80),
                                  Center(
                                    child: Text(
                                      'No rides yet',
                                      style: TextStyle(color: AppTheme.textSecondary),
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                children: [
                                  for (final group in groups) ...[
                                    _dayHeader(group.day, group.rides),
                                    for (final ride in group.rides)
                                      _buildSpendItem(ride),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryHeader(({int totalTrips, double totalSpent, int completed}) summary) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total spent (completed)', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(
            '₹${summary.totalSpent.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${summary.completed} completed · ${summary.totalTrips} total bookings',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _dayHeader(DateTime day, List<Map<String, dynamic>> rides) {
    final daySum = RideHistoryFormat.daySummary(rides);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              RideHistoryFormat.formatDayHeader(day),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '₹${daySum.spent.toStringAsFixed(0)}',
            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendItem(Map<String, dynamic> o) {
    final rideId = RideHistoryFormat.rideId(o);
    final pickup = RideHistoryFormat.addressFrom(o, nestedKey: 'pickup');
    final drop = RideHistoryFormat.addressFrom(o, nestedKey: 'drop');
    final fare = RideHistoryFormat.fareAmount(o);
    final status = RideHistoryFormat.status(o);
    final when = RideHistoryFormat.formatDateTime(o);
    final driver = RideHistoryFormat.driverName(o);
    final payment = (o['payment_mode'] ?? '—').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  when,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
              Text(
                status == 'COMPLETED' ? '-₹${fare.toStringAsFixed(0)}' : '₹${fare.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: status == 'COMPLETED' ? AppTheme.danger : AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(pickup, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          Text(drop, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            [
              if (driver != null) 'Driver: $driver',
              'Payment: $payment',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
