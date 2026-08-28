import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/booking_draft_store.dart';
import '../../widgets/app_map_view.dart';
import '../../services/route_service.dart';
import '../../services/ride_flow_service.dart';
import '../../services/ride_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fare_calculator.dart';

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({super.key});

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  String _payment = 'Cash';
  bool _confirming = false;
  final _routeService = RouteService();
  bool _routeLoading = false;
  List<LatLng> _routePoints = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRouteIfNeeded();
  }

  Future<void> _loadRouteIfNeeded() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    LatLng? pickupLatLng = args?['pickupLatLng'] is LatLng
        ? args!['pickupLatLng'] as LatLng
        : null;
    LatLng? dropoffLatLng = args?['dropoffLatLng'] is LatLng
        ? args!['dropoffLatLng'] as LatLng
        : null;

    if (pickupLatLng == null || dropoffLatLng == null) {
      final draft = await BookingDraftStore.load();
      if (draft != null) {
        final pLat = (draft['pickupLat'] as num?)?.toDouble();
        final pLng = (draft['pickupLng'] as num?)?.toDouble();
        final dLat = (draft['dropLat'] as num?)?.toDouble();
        final dLng = (draft['dropLng'] as num?)?.toDouble();
        if (pLat != null && pLng != null) pickupLatLng = LatLng(pLat, pLng);
        if (dLat != null && dLng != null) dropoffLatLng = LatLng(dLat, dLng);
      }
    }

    if (pickupLatLng == null || dropoffLatLng == null) return;
    if (_routeLoading || _routePoints.isNotEmpty) return;

    setState(() => _routeLoading = true);
    try {
      final pts = await _routeService.getRoute(
        startLat: pickupLatLng.latitude,
        startLng: pickupLatLng.longitude,
        endLat: dropoffLatLng.latitude,
        endLng: dropoffLatLng.longitude,
      );
      if (!mounted) return;
      setState(() => _routePoints = pts);
    } catch (e) {
      print('OSRM route error: $e');
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final pickupAddress = args?['pickupAddress']?.toString() ??
        args?['pickup']?.toString() ??
        '—';
    final dropAddress = args?['dropoffAddress']?.toString() ??
        args?['dropoff']?.toString() ??
        '—';
    final taxiType = args?['taxiType']?.toString() ?? '—';
    final maxPassengers = (args?['maxPassengers'] is num)
        ? (args!['maxPassengers'] as num).toInt()
        : null;
    final rideId = args?['rideId']?.toString() ?? '';
    final distanceKm = (args?['distanceKm'] is num)
        ? (args!['distanceKm'] as num).toDouble()
        : 17.2;
    final durationMin = (args?['durationMin'] is num)
        ? (args!['durationMin'] as num).toDouble()
        : 20.0;
    final perKmRate = (args?['perKmRate'] is num)
        ? (args!['perKmRate'] as num).toDouble()
        : FareCalculator.ratePerKm;
    final fare = (args?['fare'] is num)
        ? (args!['fare'] as num).toDouble()
        : FareCalculator.calculateFare(distanceKm, ratePerKmOverride: perKmRate);
    final pickupLatLng = args?['pickupLatLng'] is LatLng
        ? args!['pickupLatLng'] as LatLng
        : null;
    final dropoffLatLng = args?['dropoffLatLng'] is LatLng
        ? args!['dropoffLatLng'] as LatLng
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Booking Summary',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 220,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppMapView(
                    pickup: pickupLatLng,
                    drop: dropoffLatLng,
                    routePoints: _routePoints.isNotEmpty ? _routePoints : null,
                    initialCenter: pickupLatLng ?? dropoffLatLng,
                    initialZoom: 13.5,
                    showRoute: true,
                    interactive: true,
                  ),
                ),
                if (_routeLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withAlpha(140),
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Container(
                    decoration: AppTheme.cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trip Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _rowLabelValue('Pickup', pickupAddress),
                        const SizedBox(height: 8),
                        _rowLabelValue('Drop', dropAddress),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        _rowTwo(
                          'Distance',
                          FareCalculator.formatDistance(distanceKm),
                          'Duration',
                          FareCalculator.formatDuration(durationMin),
                        ),
                        const SizedBox(height: 8),
                        _rowTwo(
                          'Total Fare',
                          FareCalculator.formatFare(fare),
                          'Vehicle',
                          maxPassengers == null
                              ? taxiType
                              : '$taxiType ($maxPassengers seats)',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          distanceKm < 1
                              ? '₹${perKmRate.toStringAsFixed(0)}/km minimum (short trip)'
                              : '₹${perKmRate.toStringAsFixed(0)}/km × ${distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _paymentCard(
                          label: 'Cash',
                          icon: Icons.payments_outlined,
                          selected: _payment == 'Cash',
                          onTap: () => setState(() => _payment = 'Cash'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _paymentCard(
                          label: 'Razorpay\n(UPI / Card)',
                          icon: Icons.payment,
                          selected: _payment == 'Online',
                          onTap: () => setState(() => _payment = 'Online'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  onPressed: _confirming
                      ? null
                      : () async {
                          if (rideId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Invalid ride. Please try again.')),
                            );
                            return;
                          }
                          setState(() => _confirming = true);
                          try {
                            final confirmedRide = await RideService.confirmRide(
                              rideId: rideId,
                              paymentMode:
                                  _payment == 'Online' ? 'ONLINE' : 'CASH',
                            );
                            await RideFlowService.afterConfirmRide(rideId);
                            if (!mounted) return;
                            Navigator.pushReplacementNamed(
                              context,
                              '/driver-searching',
                              arguments: {
                                ...(args ?? {}),
                                'paymentMethod': _payment,
                                'pickupLatLng': pickupLatLng,
                                'dropoffLatLng': dropoffLatLng,
                                'rideId': rideId,
                                'fare': fare,
                                'distanceKm': distanceKm,
                                'durationMin': durationMin,
                                'otp': confirmedRide.otp,
                              },
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to confirm ride: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _confirming = false);
                          }
                        },
                    child: Text(
                      _confirming ? 'CONFIRMING...' : 'CONFIRM RIDE',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowLabelValue(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowTwo(String l1, String v1, String l2, String v2) {
    return Row(
      children: [
        Expanded(child: _metric(l1, v1)),
        const SizedBox(width: 12),
        Expanded(child: _metric(l2, v2)),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: 2),
          color:
              selected ? AppTheme.primary.withAlpha(20) : AppTheme.surfaceLight,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.primary : AppTheme.textPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}
