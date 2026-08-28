import 'package:flutter/material.dart';

import '../../../services/ride_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/ride_history_format.dart';

class RidesDetailScreen extends StatefulWidget {
  const RidesDetailScreen({super.key});

  @override
  State<RidesDetailScreen> createState() => _RidesDetailScreenState();
}

class _RidesDetailScreenState extends State<RidesDetailScreen> {
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
      final list = <Map<String, dynamic>>[];
      for (final o in raw) {
        if (o is Map) list.add(Map<String, dynamic>.from(o));
      }
      if (!mounted) return;
      setState(() {
        _orders = list;
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
    final groups = RideHistoryFormat.groupByDay(_orders);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Ride History', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
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
              : RefreshIndicator(
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
                              for (final ride in group.rides) _buildRideItem(ride),
                            ],
                          ],
                        ),
                ),
    );
  }

  Widget _dayHeader(DateTime day, List<Map<String, dynamic>> rides) {
    final summary = RideHistoryFormat.daySummary(rides);
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
                fontSize: 15,
              ),
            ),
          ),
          Text(
            '${summary.trips} trips · ₹${summary.spent.toStringAsFixed(0)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRideItem(Map<String, dynamic> o) {
    final rideId = RideHistoryFormat.rideId(o);
    final driverName = RideHistoryFormat.driverName(o) ?? 'Driver pending';
    final pickup = RideHistoryFormat.addressFrom(o, nestedKey: 'pickup');
    final drop = RideHistoryFormat.addressFrom(o, nestedKey: 'drop');
    final fare = RideHistoryFormat.fareAmount(o);
    final status = RideHistoryFormat.status(o);
    final when = RideHistoryFormat.formatDateTime(o);

    return InkWell(
      onTap: rideId.isEmpty
          ? null
          : () => Navigator.pushNamed(
                context,
                '/ride-history-detail',
                arguments: {'rideId': rideId},
              ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              child: const Icon(Icons.person, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driverName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(when, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    pickup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                  Text(
                    drop,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: status == 'COMPLETED'
                          ? AppTheme.success
                          : status == 'CANCELLED'
                              ? AppTheme.danger
                              : AppTheme.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₹${fare.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
