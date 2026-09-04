import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:taxiapp/api/api_result.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/core/app_colors.dart';

import '../ride_flow_navigator.dart';
import '../ride_flow_routes.dart';
import '../ride_flow_service.dart';
import '../widgets/ride_flow_scaffold.dart';
import '../widgets/ride_map_widget.dart';
import '../widgets/ride_nav_banner.dart';
import '../widgets/slide_to_confirm.dart';
import '../widgets/driver_cancel_ride.dart';

/// Page 1 — Ride accepted: OSRM navigation to pickup, swipe ARRIVED.
class RideAcceptedPage extends StatefulWidget {
  const RideAcceptedPage({super.key});

  @override
  State<RideAcceptedPage> createState() => _RideAcceptedPageState();
}

class _RideAcceptedPageState extends State<RideAcceptedPage> {
  final _flow = RideFlowService.instance;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _flow.rideNotifier.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRoute());
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshRoute() async {
    await _flow.loadRoute(toPickup: true);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flow.rideNotifier.removeListener(_rebuild);
    super.dispose();
  }

  Future<void> _onArrived() async {
    if (_loading) return;
    final token = await _flow.requireToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _loading = true);
    final result = await DriverApi.withToken(token).markArrivedResult(_flow.rideId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.success && !_flowApiIdempotentArrived(result)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Could not mark arrived'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (result.data is Map) {
      final body = Map<String, dynamic>.from(result.data as Map);
      if (body['ride'] is Map) {
        _flow.mergeRide(Map<String, dynamic>.from(body['ride'] as Map));
      }
    }
    _flow.mergeRide({..._flow.ride, 'status': 'ARRIVED_AT_PICKUP'});
    await RideFlowNavigator.go(context, RideFlowRoutes.arrived);
  }

  bool _flowApiIdempotentArrived(ApiResult result) {
    final msg = (result.message ?? '').toLowerCase();
    return msg.contains('already') || msg.contains('arrived');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _flow.rideNotifier,
      builder: (context, _) {
        final ride = _flow.ride;
        final phone = _flow.customerPhone();
        final nearPickup = _flow.isNearPickup;
        final canCancel = ride['otp_verified'] != true &&
            !['STARTED', 'PICKED_UP', 'IN_TRANSIT', 'COMPLETED'].contains(_flow.status.toUpperCase());

        return RideFlowScaffold(
          title: 'Ride Accepted',
          canPop: true,
          bottomButton: SlideToConfirm(
            label: nearPickup ? 'Swipe to confirm ARRIVED' : 'Drive closer to pickup to swipe',
            enabled: (nearPickup || kIsWeb) && !_loading,
            onConfirmed: _onArrived,
          ),
          children: [
            RideNavBanner(
              step: _flow.currentNavStep,
              distanceKm: _flow.routeDistanceKm,
              etaMin: _flow.routeEtaMin,
              subtitle: 'To pickup · ${_flow.routeDistanceKm.toStringAsFixed(1)} km · '
                  '${_flow.routeEtaMin.round()} min',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_flow.customerName(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (phone.isNotEmpty) Text('Mobile: $phone'),
                    const SizedBox(height: 8),
                    Text('Pickup: ${_flow.locationLabel(ride['pickup'], fallback: 'Pickup')}'),
                    Text('Drop: ${_flow.locationLabel(ride['drop'] ?? ride['dropoff'], fallback: 'Drop')}'),
                    Text('Fare est.: ₹${_flow.fare.toStringAsFixed(0)}'),
                    if (!nearPickup)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Get within ${RideFlowService.pickupGeofenceM.round()} m of pickup to swipe ARRIVED',
                          style: const TextStyle(color: AppColors.gold, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showPhoneActions(context, phone),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showPhoneActions(context, phone),
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                  ),
                ),
              ],
            ),
            if (canCancel) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => showDriverCancelRideDialog(context),
                icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                label: const Text('Cancel Ride', style: TextStyle(color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: 12),
            RideMapWidget(
              driver: _flow.currentLocation ?? _flow.pickup,
              pickup: _flow.pickup,
              drop: _flow.drop,
              route: _flow.routePolyline,
              heading: _flow.heading,
              customerLabel: _flow.customerName(),
              onRefreshLocation: _flow.refreshDriverLocation,
            ),
          ],
        );
      },
    );
  }
}
