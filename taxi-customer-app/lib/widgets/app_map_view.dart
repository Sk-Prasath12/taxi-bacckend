import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DriverMarkerFrame {
  final LatLng position;
  final double bearing;

  const DriverMarkerFrame({
    required this.position,
    required this.bearing,
  });
}

class AppMapView extends StatelessWidget {
  final MapController? mapController;
  final LatLng? pickup;
  final LatLng? drop;
  final LatLng? driver;
  final LatLng? customer;
  final ValueListenable<LatLng?>? customerListenable;
  final ValueListenable<DriverMarkerFrame?>? driverListenable;
  final List<LatLng>? routePoints;
  final LatLng? initialCenter;
  final double initialZoom;
  final bool showRoute;
  final bool interactive;
  final double routeProgress;
  final bool navigationMode;
  final VoidCallback? onMapReady;
  final void Function(MapEvent event)? onMapEvent;
  final void Function(LatLng center, double zoom)? onPositionChanged;
  final void Function(LatLng point)? onTap;

  const AppMapView({
    super.key,
    this.mapController,
    this.pickup,
    this.drop,
    this.driver,
    this.customer,
    this.customerListenable,
    this.driverListenable,
    this.routePoints,
    this.initialCenter,
    this.initialZoom = 14,
    this.showRoute = true,
    this.interactive = true,
    this.routeProgress = 1,
    this.navigationMode = false,
    this.onMapReady,
    this.onMapEvent,
    this.onPositionChanged,
    this.onTap,
  });

  static const String _taxiAsset = 'assets/traveling page/taxi_drive.png';

  @override
  Widget build(BuildContext context) {
    final center = initialCenter ?? pickup ?? drop ?? const LatLng(20.5937, 78.9629);
    final polyline = (routePoints != null && routePoints!.length >= 2) ? routePoints! : <LatLng>[];
    final progress = routeProgress.clamp(0.0, 1.0);
    final completedPolyline = _sliceRouteByProgress(polyline, progress);
    final remainingPolyline = polyline.length >= 2
        ? polyline.sublist((completedPolyline.length - 1).clamp(0, polyline.length - 1))
        : <LatLng>[];

    return RepaintBoundary(
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: initialZoom,
          onMapReady: onMapReady,
          onMapEvent: onMapEvent,
          onTap: onTap == null
              ? null
              : (tapPosition, point) => onTap!(point),
          onPositionChanged: onPositionChanged == null
              ? null
              : (camera, hasGesture) {
                  if (!hasGesture) return;
                  final c = camera.center;
                  final z = camera.zoom;
                  if (c == null || z == null) return;
                  onPositionChanged!(c, z);
                },
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.manimaran.taxi_user',
          ),
          if (showRoute && polyline.length >= 2)
            PolylineLayer(
              polylines: [
                if (navigationMode && completedPolyline.length >= 2)
                  Polyline(
                    points: completedPolyline,
                    strokeWidth: 6,
                    color: const Color(0xFF111111),
                  ),
                Polyline(
                  points: navigationMode ? remainingPolyline : polyline,
                  strokeWidth: navigationMode ? 6 : 4,
                  color: navigationMode ? const Color(0xFFFDB813) : Colors.green,
                ),
              ],
            ),
          if (customerListenable != null)
            ValueListenableBuilder<LatLng?>(
              valueListenable: customerListenable!,
              builder: (context, customerPos, _) {
                return _buildCustomerMarker(customerPos);
              },
            )
          else if (customer != null)
            _buildCustomerMarker(customer),
          if (driverListenable != null)
            ValueListenableBuilder<DriverMarkerFrame?>(
              valueListenable: driverListenable!,
              builder: (context, driverFrame, _) {
                return _buildMarkerLayer(driverFrame, customerPos: null);
              },
            )
          else
            _buildMarkerLayer(
              driver == null ? null : DriverMarkerFrame(position: driver!, bearing: 0),
              customerPos: customer,
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerMarker(LatLng? pos) {
    if (pos == null) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [
        Marker(
          point: pos,
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkerLayer(DriverMarkerFrame? driverFrame, {LatLng? customerPos}) {
    return MarkerLayer(
      markers: [
        if (customerPos != null)
          Marker(
            point: customerPos,
            width: 36,
            height: 36,
            child: const Icon(Icons.my_location, color: Colors.blue, size: 28),
          ),
        if (pickup != null)
          Marker(
            point: pickup!,
            width: 40,
            height: 40,
            alignment: Alignment.bottomCenter,
            child: const Icon(Icons.location_on, color: Colors.green, size: 36),
          ),
        if (drop != null)
          Marker(
            point: drop!,
            width: 40,
            height: 40,
            alignment: Alignment.bottomCenter,
            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
          ),
        if (driverFrame != null)
          Marker(
            point: driverFrame.position,
            width: 44,
            height: 44,
            alignment: Alignment.bottomCenter,
            child: RepaintBoundary(
              child: Transform.rotate(
                angle: driverFrame.bearing * (3.141592653589793 / 180),
                child: Image.asset(
                  _taxiAsset,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.directions_car,
                    color: Color(0xFF1A1A1A),
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<LatLng> _sliceRouteByProgress(List<LatLng> route, double progress) {
    if (route.length < 2) return route;
    if (progress <= 0) return <LatLng>[route.first];
    if (progress >= 1) return route;

    final totalSegments = route.length - 1;
    final scaled = progress * totalSegments;
    final upto = scaled.floor().clamp(0, totalSegments - 1);
    final localT = scaled - upto;

    final points = <LatLng>[...route.take(upto + 1)];
    final a = route[upto];
    final b = route[upto + 1];
    points.add(
      LatLng(
        a.latitude + (b.latitude - a.latitude) * localT,
        a.longitude + (b.longitude - a.longitude) * localT,
      ),
    );
    return points;
  }
}

