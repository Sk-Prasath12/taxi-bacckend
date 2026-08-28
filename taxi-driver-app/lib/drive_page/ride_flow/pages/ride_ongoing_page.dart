import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/fare_calculator.dart';

import '../ride_flow_navigator.dart';
import '../ride_flow_routes.dart';
import '../ride_flow_service.dart';
import '../widgets/ride_flow_scaffold.dart';
import '../widgets/ride_map_widget.dart';
import '../widgets/ride_nav_banner.dart';
import '../widgets/slide_to_confirm.dart';

/// Live trip to drop — customer can get off anywhere; fare = GPS km only.
class RideOngoingPage extends StatefulWidget {
  const RideOngoingPage({super.key});

  @override
  State<RideOngoingPage> createState() => _RideOngoingPageState();
}

class _RideOngoingPageState extends State<RideOngoingPage> {
  final _flow = RideFlowService.instance;

  @override
  void initState() {
    super.initState();
    _flow.rideNotifier.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _flow.loadRoute(toPickup: false);
      if (mounted) setState(() {});
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flow.rideNotifier.removeListener(_rebuild);
    super.dispose();
  }

  Future<void> _dropReached() async {
    await RideFlowNavigator.go(context, RideFlowRoutes.dropReached);
  }

  @override
  Widget build(BuildContext context) {
    final kmFare = _flow.tripTracker.estimateKmOnlyFare();

    return RideFlowScaffold(
      title: 'Trip to Drop',
      canPop: true,
      bottomButton: SlideToConfirm(
        label: 'Swipe when customer gets off',
        enabled: true,
        onConfirmed: _dropReached,
      ),
      children: [
        RideNavBanner(
          step: _flow.currentNavStep,
          distanceKm: _flow.routeDistanceKm,
          etaMin: _flow.routeEtaMin,
          subtitle: 'OSRM route to drop · ${_flow.routeDistanceKm.toStringAsFixed(1)} km · '
              '${_flow.routeEtaMin.round()} min',
        ),
        const SizedBox(height: 12),
        Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _chip('${_flow.tripTracker.distanceKm.toStringAsFixed(2)} km travelled', Icons.route),
                _chip('₹${kmFare.round()} fare', Icons.payments),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Customer can get off anywhere. Fare = '
            '${_flow.tripTracker.distanceKm.toStringAsFixed(2)} km × '
            '₹${FareCalculator.perKm.toStringAsFixed(0)}/km only.',
            style: const TextStyle(color: AppColors.gold, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Text('Customer: ${_flow.customerName()}'),
        const SizedBox(height: 12),
        RideMapWidget(
          driver: _flow.currentLocation ?? _flow.drop,
          pickup: _flow.pickup,
          drop: _flow.drop,
          route: _flow.routePolyline,
          heading: _flow.heading,
          customerLabel: _flow.customerName(),
          onRefreshLocation: _flow.refreshDriverLocation,
        ),
      ],
    );
  }

  Widget _chip(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mapRoute),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
