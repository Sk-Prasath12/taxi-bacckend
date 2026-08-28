import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/utils/ride_navigation_utils.dart';

/// OSRM navigation map with route, markers, and "My location" button.
class RideMapWidget extends StatefulWidget {
  final LatLng? driver;
  final LatLng? pickup;
  final LatLng? drop;
  final List<LatLng> route;
  final double heading;
  final double height;
  final bool followDriver;
  final String? customerLabel;
  final Future<LatLng?> Function()? onRefreshLocation;

  const RideMapWidget({
    super.key,
    this.driver,
    this.pickup,
    this.drop,
    this.route = const [],
    this.heading = 0,
    this.height = 360,
    this.followDriver = false,
    this.customerLabel,
    this.onRefreshLocation,
  });

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> {
  final MapController _mapController = MapController();
  String _lastFitKey = '';
  bool _locating = false;

  @override
  void didUpdateWidget(RideMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleFit();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleFit());
  }

  void _scheduleFit() {
    final key = _fitKey;
    if (key == _lastFitKey) {
      if (widget.followDriver && widget.driver != null) {
        _moveCamera(widget.driver!, _mapController.camera.zoom.clamp(14.0, 17.0));
      }
      return;
    }
    _lastFitKey = key;
    _fitAllPoints();
  }

  /// Route/pickup/drop only — driver GPS updates must not re-fit the whole map.
  String get _fitKey {
    final p = widget.pickup;
    final dr = widget.drop;
    final r = widget.route;
    final routeKey = r.length < 2
        ? '${r.length}'
        : '${r.length}|${r.first.latitude},${r.first.longitude}|${r.last.latitude},${r.last.longitude}';
    return '${p?.latitude},${p?.longitude}|${dr?.latitude},${dr?.longitude}|$routeKey';
  }

  List<LatLng> _allPoints() {
    final points = <LatLng>[];
    if (widget.route.isNotEmpty) points.addAll(widget.route);
    if (widget.driver != null) points.add(widget.driver!);
    if (widget.pickup != null) points.add(widget.pickup!);
    if (widget.drop != null) points.add(widget.drop!);
    return points;
  }

  void _moveCamera(LatLng dest, double zoom) {
    try {
      _mapController.move(dest, zoom);
    } catch (_) {}
  }

  void _fitAllPoints() {
    final points = _allPoints();
    if (points.isEmpty) return;

    if (points.length == 1) {
      _moveCamera(points.first, 16);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    final fit = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(56),
    ).fit(_mapController.camera);
    _moveCamera(fit.center, fit.zoom.clamp(11.0, 17.0));
  }

  Future<void> _onMyLocationNow() async {
    if (_locating) return;
    setState(() => _locating = true);

    LatLng? target = widget.driver;
    if (widget.onRefreshLocation != null) {
      target = await widget.onRefreshLocation!();
    }

    if (!mounted) return;
    setState(() => _locating = false);

    target ??= widget.driver ?? widget.pickup;
    if (target != null) {
      _moveCamera(target, 16.5);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location. Enable GPS.')),
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Widget _pin({required IconData icon, required Color color, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 32),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.driver ?? widget.pickup ?? widget.drop ?? const LatLng(12.97, 80.22);
    final customerAt = widget.pickup;

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.taxiapp.driver',
                ),
                if (widget.route.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.route,
                        strokeWidth: 14,
                        color: AppColors.mapRouteDark,
                      ),
                      Polyline(
                        points: widget.route,
                        strokeWidth: 7,
                        color: AppColors.mapRoute,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (widget.pickup != null)
                      Marker(
                        point: widget.pickup!,
                        width: 80,
                        height: 58,
                        alignment: Alignment.bottomCenter,
                        child: _pin(
                          icon: widget.drop != null &&
                                  RideNavigationUtils.samePlace(widget.pickup!, widget.drop!)
                              ? Icons.location_on
                              : Icons.trip_origin,
                          color: AppColors.green,
                          label: widget.drop != null &&
                                  RideNavigationUtils.samePlace(widget.pickup!, widget.drop!)
                              ? 'Pickup · Drop'
                              : 'Pickup',
                        ),
                      ),
                    if (customerAt != null &&
                        widget.pickup != null &&
                        RideNavigationUtils.samePlace(customerAt, widget.pickup!))
                      Marker(
                        point: LatLng(
                          customerAt.latitude + 0.00015,
                          customerAt.longitude + 0.00012,
                        ),
                        width: 80,
                        height: 58,
                        alignment: Alignment.bottomCenter,
                        child: _pin(
                          icon: Icons.person_pin_circle,
                          color: AppColors.gold,
                          label: widget.customerLabel ?? 'Customer',
                        ),
                      ),
                    if (widget.drop != null &&
                        (widget.pickup == null ||
                            !RideNavigationUtils.samePlace(widget.pickup!, widget.drop!)))
                      Marker(
                        point: widget.drop!,
                        width: 80,
                        height: 58,
                        alignment: Alignment.bottomCenter,
                        child: _pin(icon: Icons.place, color: Colors.redAccent, label: 'Drop'),
                      ),
                    if (widget.driver != null)
                      Marker(
                        point: widget.driver!,
                        width: 44,
                        height: 44,
                        child: Transform.rotate(
                          angle: widget.heading * math.pi / 180,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.mapDriver,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black45, blurRadius: 6, spreadRadius: 1),
                              ],
                            ),
                            child: const Icon(Icons.navigation, color: AppColors.scaffoldDark, size: 26),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Material(
                    color: AppColors.cardDarkElevated,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 4,
                    child: InkWell(
                      onTap: _fitAllPoints,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.map_outlined, color: AppColors.mapRoute, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 4,
                    child: InkWell(
                      onTap: _locating ? null : _onMyLocationNow,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_locating)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.cardDark,
                                ),
                              )
                            else
                              const Icon(Icons.my_location, color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            const Text(
                              'Now',
                              style: TextStyle(
                                color: AppColors.cardDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
