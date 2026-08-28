import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/ride_service.dart';

class DistanceDetailScreen extends StatefulWidget {
  const DistanceDetailScreen({super.key});

  @override
  State<DistanceDetailScreen> createState() => _DistanceDetailScreenState();
}

class _DistanceDetailScreenState extends State<DistanceDetailScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rides = const [];
  double _totalKm = 0;

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
      final rides = <Map<String, dynamic>>[];
      var total = 0.0;
      for (final item in raw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final km = m['distance_km'];
        if (km is num) total += km.toDouble();
        rides.add(m);
      }
      if (!mounted) return;
      setState(() {
        _rides = rides;
        _totalKm = total;
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

  String _label(Map<String, dynamic> ride) {
    final pickup = ride['pickup'] is Map ? (ride['pickup'] as Map)['address']?.toString() : null;
    final drop = ride['drop'] is Map ? (ride['drop'] as Map)['address']?.toString() : null;
    if (pickup != null && drop != null && pickup.isNotEmpty && drop.isNotEmpty) {
      final p = pickup.split(',').first.trim();
      final d = drop.split(',').first.trim();
      return '$p → $d';
    }
    return 'Ride ${(ride['ride_id'] ?? ride['id'] ?? '').toString()}';
  }

  String _date(Map<String, dynamic> ride) {
    final raw = ride['createdAt']?.toString() ?? ride['created_at']?.toString();
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distance Traveled', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFDB813),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDB813)),
                        ),
                        child: Text(
                          'Total: ${_totalKm.toStringAsFixed(1)} km across ${_rides.length} rides',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (_rides.isEmpty)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No ride distance data yet'),
                        ))
                      else
                        ..._rides.map(_buildDistanceItem),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDistanceItem(Map<String, dynamic> ride) {
    final km = ride['distance_km'];
    final kmText = km is num ? '${km.toStringAsFixed(1)} KM' : '—';
    final rideId = (ride['ride_id'] ?? ride['id'])?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: rideId.isEmpty
            ? null
            : () => Navigator.pushNamed(
                  context,
                  '/ride-history-detail',
                  arguments: {'rideId': rideId},
                ),
        child: Column(
          children: [
            Container(
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F4FC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: const Center(
                child: Icon(Icons.route, color: Color(0xFF1976D2), size: 36),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_label(ride), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(_date(ride), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(kmText, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
