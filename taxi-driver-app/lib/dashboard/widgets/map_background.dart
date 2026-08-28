import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/widgets/taxi_loading.dart';

class MapBackground extends StatefulWidget {
  final LatLng? pickupPoint;
  final LatLng? dropPoint;
  final ValueChanged<double>? onDistanceCalculated;

  const MapBackground({
    super.key,
    this.pickupPoint,
    this.dropPoint,
    this.onDistanceCalculated,
  });

  @override
  State<MapBackground> createState() => _MapBackgroundState();
}

class _MapBackgroundState extends State<MapBackground>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(12.97, 80.25); // Default: Chennai
  List<LatLng> _isochronePoints = [];
  List<LatLng> _routePoints = []; // Route logic

  bool _hasLocation = false;
  bool _permissionDenied = false;
  bool _permissionDeniedForever = false;
  bool _isLoading = true;
  StreamSubscription<Position>? _positionStreamSubscription;
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermission();
    _fetchIsochrone();
    _fetchRoute();
  }

  @override
  void didUpdateWidget(MapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pickupPoint != oldWidget.pickupPoint ||
        widget.dropPoint != oldWidget.dropPoint) {
      _fetchRoute();
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _animationController?.dispose();

    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    final Animation<double> animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );

    _animationController!.addListener(() {
      if (mounted) {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      }
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _animationController?.dispose();
        _animationController = null;
      }
    });

    _animationController!.forward();
  }

  Future<void> _fetchRoute() async {
    if (widget.pickupPoint == null || widget.dropPoint == null) {
      if (mounted) setState(() => _routePoints = []);
      return;
    }

    // Use OSRM Public API for demo route
    final start = widget.pickupPoint!;
    final end = widget.dropPoint!;
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          final distanceMeters =
              route['distance'] as num; // OSRM returns meters

          if (widget.onDistanceCalculated != null) {
            widget.onDistanceCalculated!(
              distanceMeters / 1000,
            ); // Convert to km
          }

          final List<LatLng> points = coordinates
              .map((coord) => LatLng(coord[1], coord[0]))
              .toList();

          if (mounted) {
            setState(() {
              _routePoints = points;
            });
            // Auto-fit bounds with animation
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                final bounds = LatLngBounds.fromPoints(_routePoints);
                final centerZoom = CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50),
                ).fit(_mapController.camera);
                _animatedMapMove(centerZoom.center, centerZoom.zoom);
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
      // Fallback to straight line
      if (mounted) {
        setState(() {
          _routePoints = [widget.pickupPoint!, widget.dropPoint!];
        });
      }
    }
  }

  Future<void> _fetchIsochrone() async {
    // API cleared. Relying on default CircleLayer fallback for demo.
    if (mounted) {
      setState(() {
        _isochronePoints = [];
      });
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermission() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
      _permissionDeniedForever = false;
    });

    if (kIsWeb) {
      await _startLiveLocationUpdates(webFallback: true);
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _permissionDenied = true;
        });
      }
      _showLocationServiceDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _permissionDenied = true;
        });
      }
      _showPermissionDialog();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _permissionDeniedForever = true;
        });
      }
      _showPermissionDeniedForeverDialog();
      return;
    }

    // Permission granted, start location updates
    await _startLiveLocationUpdates();
  }

  Future<void> _startLiveLocationUpdates({bool webFallback = false}) async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
      _permissionDeniedForever = false;
    });

    if (webFallback) {
      setState(() {
        _hasLocation = true;
        _isLoading = false;
      });
      _mapController.move(_currentLocation, 14.0);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _permissionDenied = webFallback || kIsWeb;
        _permissionDeniedForever =
            permission == LocationPermission.deniedForever;
      });
      if (!webFallback && !kIsWeb) return;
    }

    // Try to get last known location first for speed
    try {
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (!mounted) return;
      if (lastPosition != null) {
        setState(() {
          _currentLocation = LatLng(
            lastPosition.latitude,
            lastPosition.longitude,
          );
          _hasLocation = true;
          _isLoading = false;
        });
        _mapController.move(_currentLocation, 15.0);
      }
    } catch (e) {
      // Ignore errors here
      if (!mounted) return;
    }

    // Refresh GPS without blocking the map if we already have last known position.
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: _hasLocation ? 3 : 5),
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _hasLocation = true;
        _isLoading = false;
      });
      _mapController.move(_currentLocation, 15.0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      // If we have no location at all (not even last known), we could show error
      if (!_hasLocation) {
        debugPrint("Error getting location: $e");
      }
    }

    // Start listening to location updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
              _hasLocation = true;
            });
            _mapController.move(_currentLocation, 15.0);
          }
        });
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Location Service Disabled')),
            ],
          ),
          content: const Text(
            'Please enable location services in your device settings to view the map and your current location.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
                _checkAndRequestPermission();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: AppColors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Location Permission Required')),
            ],
          ),
          content: const Text(
            'This app needs access to your location to show your position on the map and provide route information. Please grant location permission.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                LocationPermission permission =
                    await Geolocator.requestPermission();
                if (permission == LocationPermission.whileInUse ||
                    permission == LocationPermission.always) {
                  await _startLiveLocationUpdates();
                } else {
                  _checkAndRequestPermission();
                }
              },
              child: const Text('Grant Permission'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_disabled, color: Colors.red),
              SizedBox(width: 8),
              Expanded(child: Text('Location Permission Denied')),
            ],
          ),
          content: const Text(
            'Location permission has been permanently denied. Please enable it in your device settings to view the map and routes.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
                _checkAndRequestPermission();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.taxiapp.driver',
                maxZoom: 19,
              ),
            // Route Line
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.0,
                    color: AppColors.green,
                  ),
                ],
              ),
            // Pickup/Drop Markers
            if (widget.pickupPoint != null && widget.dropPoint != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.pickupPoint!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
                  Marker(
                    point: widget.dropPoint!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            if (_isochronePoints.isNotEmpty)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _isochronePoints,
                    color: const Color(0xFF00897B).withValues(alpha: 0.3),
                    borderColor: const Color(0xFF004D40),
                    borderStrokeWidth: 3,
                  ),
                ],
              )
            else
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: const LatLng(11.1018, 79.6524), // Mayiladuthurai
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderColor: AppColors.green.withValues(alpha: 0.3),
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: 13000,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (_hasLocation)
                  Marker(
                    point: _currentLocation,
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing circle effect
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green.withValues(alpha: 0.2),
                          ),
                        ),
                        // Outer circle
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green.withValues(alpha: 0.3),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        // Inner dot (your location)
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        // Loading indicator
        if (_isLoading)
          Container(
            color: AppColors.scaffoldDark.withValues(alpha: 0.55),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TaxiLoader(size: 40),
                  SizedBox(height: 16),
                  Text(
                    'Loading map…',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if ((_permissionDenied || _permissionDeniedForever) && !_isLoading)
          Positioned(
            left: 16,
            right: 16,
            bottom: 120,
            child: Material(
              color: AppColors.cardDark.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(14),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      _permissionDeniedForever ? Icons.location_disabled : Icons.location_off,
                      color: _permissionDeniedForever ? AppColors.danger : AppColors.gold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _permissionDeniedForever
                            ? 'Enable location in browser settings to show your position.'
                            : 'Allow location to center the map on you.',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (_permissionDeniedForever) {
                          await Geolocator.openAppSettings();
                        } else {
                          await _checkAndRequestPermission();
                        }
                      },
                      child: const Text('Enable'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Relocate Button
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton(
            heroTag: "relocate_btn",
            mini: true,
            backgroundColor: AppColors.cardDark,
            onPressed: () {
              if (_hasLocation) {
                _mapController.move(_currentLocation, 15.0);
              } else {
                _checkAndRequestPermission();
              }
            },
            child: const Icon(Icons.my_location, color: AppColors.green),
          ),
        ),
      ],
      ),
    );
  }
}
