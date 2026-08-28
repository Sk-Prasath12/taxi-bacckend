import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/ride_service.dart';
import '../../../utils/phone_launcher.dart';
import '../../../utils/repeat_ride.dart';

class RideHistoryDetailScreen extends StatefulWidget {
  const RideHistoryDetailScreen({super.key});

  @override
  State<RideHistoryDetailScreen> createState() => _RideHistoryDetailScreenState();
}

class _RideHistoryDetailScreenState extends State<RideHistoryDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ride;
  String _rideId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final rideId = args is String ? args : (args is Map ? args['rideId']?.toString() : null);
    if ((_rideId.isEmpty) && rideId != null && rideId.isNotEmpty) {
      _rideId = rideId;
      _load();
    }
  }

  Future<void> _load() async {
    if (_rideId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await RideService.getRideHistoryDetails(_rideId);
      final ride = res['ride'] is Map<String, dynamic> ? res['ride'] as Map<String, dynamic> : null;
      if (!mounted) return;
      setState(() {
        _ride = ride;
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

  static String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString();
    if (s.isEmpty) return '—';
    try {
      final dt = DateTime.parse(s).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return s;
    }
  }

  static String _pickAddress(Map<String, dynamic> ride, String key) {
    final v = ride[key];
    if (v is Map) {
      final addr = v['address']?.toString();
      if (addr != null && addr.trim().isNotEmpty) return addr.trim();
    }
    return '—';
  }

  static String _num(dynamic v) => v == null ? '—' : v.toString();

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    final status = (ride?['status']?.toString() ?? '—').toUpperCase();
    final fare = ride?['fare'];
    final currency = (ride?['currency']?.toString() ?? 'INR').toUpperCase();
    final paymentMode = (ride?['payment_mode']?.toString() ?? '—').toUpperCase();
    final paymentStatus = (ride?['payment_status']?.toString() ?? '—').toUpperCase();
    final pickupAddress = ride == null ? '—' : _pickAddress(ride, 'pickup');
    final dropAddress = ride == null ? '—' : _pickAddress(ride, 'drop');
    final driver = ride?['driver'] is Map ? ride!['driver'] as Map : null;
    final driverName = driver?['name']?.toString() ?? '—';
    final driverPhone = driver?['phone']?.toString() ?? '—';
    final driverStatus = (driver?['status']?.toString() ?? '—').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Ride Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFFFDB813),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
              : ride == null
                  ? const Center(child: Text('No ride details found'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(status, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                                    const SizedBox(height: 6),
                                    Text(_rideId, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    fare == null ? '—' : '₹$fare',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                  Text(currency, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(16), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Trip'),
                              _kv('Pickup', pickupAddress),
                              _kv('Drop', dropAddress),
                              const Divider(height: 24),
                              _sectionTitle('Metrics'),
                              _kv('Distance (km)', _num(ride['distance_km'])),
                              _kv('Duration (min)', _num(ride['duration_min'])),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(16), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Payment'),
                              _kv('Mode', paymentMode),
                              _kv('Status', paymentStatus),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(16), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Driver'),
                              _kv('Name', driverName),
                              _kv('Phone', driverPhone),
                              _kv('Status', driverStatus),
                              if (driverPhone != '—' && driverPhone.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => dialPhoneNumber(driverPhone),
                                          icon: const Icon(Icons.call),
                                          label: const Text('Call'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => smsPhoneNumber(driverPhone),
                                          icon: const Icon(Icons.sms_outlined),
                                          label: const Text('Text'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(16), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Security & Timestamps'),
                              _kv('OTP', ride['otp'] == null ? '—' : ride['otp'].toString()),
                              _kv('OTP Verified', (ride['otp_verified'] == true) ? 'Yes' : 'No'),
                              _kv('Created', _fmtDate(ride['createdAt'] ?? ride['created_at'])),
                              _kv('Updated', _fmtDate(ride['updatedAt'] ?? ride['updated_at'])),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => RepeatRide.fromHistoryRide(context, ride),
                                icon: const Icon(Icons.repeat),
                                label: const Text('Repeat ride'),
                              ),
                            ),
                            if (status == 'COMPLETED') ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/ride-payment',
                                    arguments: {'rideId': _rideId},
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: const Color(0xFFFDB813),
                                  ),
                                  icon: const Icon(Icons.receipt_long),
                                  label: const Text('Invoice'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
    );
  }
}

