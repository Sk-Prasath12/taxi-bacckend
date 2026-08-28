import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

import '../../widgets/app_map_view.dart';
import '../../services/route_service.dart';
import '../../services/ride_flow_service.dart';
import '../../services/ride_service.dart';
import '../../services/ride_session_cleanup.dart';
import '../../services/socket_service.dart';
import '../../utils/device_gps.dart';
import '../../utils/ride_locations.dart';
import '../../theme/app_theme.dart';

class DriverSearchingScreen extends StatefulWidget {
  const DriverSearchingScreen({super.key});

  @override
  State<DriverSearchingScreen> createState() => _DriverSearchingScreenState();
}

class _DriverSearchingScreenState extends State<DriverSearchingScreen> {
  final _routeService = RouteService();
  final _socket = SocketService.instance;
  bool _routeLoading = false;
  bool _cancelling = false;
  bool _socketListenersBound = false;
  List<LatLng> _routePoints = const [];
  Timer? _statusPoller;
  Timer? _customerLocationTimer;
  bool _navigated = false;
  String rideStatus = 'SEARCHING_DRIVER';
  void Function(dynamic)? _rideAcceptedListener;
  void Function(dynamic)? _rideStatusListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSocketListenersOnce());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRouteIfNeeded();
  }

  /// Socket.IO may send a single map or a one-element list containing the map.
  Map<String, dynamic>? _payloadAsMap(dynamic data) {
    final raw = data is List && data.isNotEmpty ? data.first : data;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  void _navigateToTracking(Map? args, Map<String, dynamic> payload, {Map<String, dynamic>? extraArgs}) {
    if (!mounted || _navigated) return;
    _navigated = true;
    _statusPoller?.cancel();
    Navigator.pushReplacementNamed(
      context,
      '/ride-tracking',
      arguments: buildRideTrackingArguments(args, payload, extraArgs: extraArgs),
    );
  }

  void _navigateToInvoice(String rideId) {
    if (!mounted || _navigated) return;
    _navigated = true;
    _statusPoller?.cancel();
    Navigator.pushReplacementNamed(context, '/ride-payment', arguments: {'rideId': rideId});
  }

  Future<void> _bindSocketListenersOnce() async {
    if (_socketListenersBound || !mounted) return;
    _socketListenersBound = true;

    await _socket.connect();
    if (!mounted) return;
    _socket.joinCustomerRoom();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final rideId = args?['rideId']?.toString();
    if (rideId != null && rideId.isNotEmpty) {
      await RideFlowService.afterConfirmRide(rideId);
      _socket.joinRideRoom(rideId);
      _startStatusPolling(rideId);
      _startCustomerLocationEmitter(rideId);
    }

    _rideAcceptedListener = (data) {
      print('Driver accepted (ride_accepted): $data');
      if (!mounted || _navigated) return;
      final map = _payloadAsMap(data);
      setState(() => rideStatus = 'ACCEPTED');
      print('CURRENT UI STATUS: $rideStatus');
      print('Navigating to tracking');
      final payloadWithStatus = <String, dynamic>{
        ...(map ?? {'ride_id': rideId}),
        'status': 'ACCEPTED',
      };
      _navigateToTracking(
        ModalRoute.of(context)?.settings.arguments as Map?,
        payloadWithStatus,
        extraArgs: {'acceptedPayload': data, 'initialStatus': 'ACCEPTED'},
      );
    };
    _rideStatusListener = (data) {
      final map = _payloadAsMap(data);
      if (!mounted || _navigated || map == null) return;
      final status = (map['status']?.toString() ?? '').toUpperCase();
      print('NEW STATUS: $status');
      setState(() => rideStatus = status.isNotEmpty ? status : rideStatus);
      print('CURRENT UI STATUS: $rideStatus');

      if (status == 'ACCEPTED') {
        print('Navigating to tracking');
        _navigateToTracking(
          ModalRoute.of(context)?.settings.arguments as Map?,
          map,
          extraArgs: {'initialStatus': 'ACCEPTED'},
        );
        return;
      }

      if (status == 'DROP_OTP_VERIFIED' || status == 'PAYMENT_PENDING') {
        final rid = map['ride_id']?.toString() ?? rideId ?? '';
        if (rid.isNotEmpty) {
          _navigated = true;
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/ride-payment',
            arguments: {'rideId': rid},
          );
        }
        return;
      }

      if (status == 'COMPLETED') {
        final rid = map['ride_id']?.toString() ?? rideId ?? '';
        if (rid.isNotEmpty) {
          _navigateToInvoice(rid);
        }
        return;
      }

      if (status == 'CANCELLED' || status == 'CANCELLED_BY_CUSTOMER') {
        _navigated = true;
        unawaited(RideSessionCleanup.clearLocalOnly());
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        return;
      }

      if (status == 'DRIVER_ASSIGNED' ||
          status == 'DRIVER_ARRIVING' ||
          status == 'DRIVER_ARRIVED' ||
          status == 'ARRIVED' ||
          status == 'ARRIVED_AT_PICKUP' ||
          status == 'OTP_VERIFIED' ||
          status == 'TRIP_STARTED' ||
          status == 'STARTED' ||
          status == 'PICKED_UP' ||
          status == 'IN_TRANSIT' ||
          status == 'IN_PROGRESS' ||
          status == 'DROP_REACHED') {
        _navigateToTracking(ModalRoute.of(context)?.settings.arguments as Map?, map);
      }
    };
    _socket.onRideAccepted(_rideAcceptedListener!);
    _socket.onRideStatusUpdate(_rideStatusListener!);
  }

  void _startCustomerLocationEmitter(String rideId) {
    _customerLocationTimer?.cancel();
    _customerLocationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _navigated) return;
      try {
        final blocked = await DeviceGps.ensureReady();
        if (blocked != null) return;
        final pos = await DeviceGps.currentLatLng();
        _socket.emitCustomerLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          rideId: rideId,
        );
      } catch (_) {}
    });
  }

  void _startStatusPolling(String rideId) {
    _statusPoller?.cancel();
    _statusPoller = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _navigated) return;
      try {
        final statusResponse = await RideService.getRideStatus(rideId);
        final status = (statusResponse['status']?.toString() ?? '').toUpperCase();
        if (!mounted || _navigated) return;
        if (status == 'COMPLETED') {
          _navigateToInvoice(rideId);
          return;
        }
        if (status == 'CANCELLED' || status == 'CANCELLED_BY_CUSTOMER') {
          _navigated = true;
          _statusPoller?.cancel();
          await RideSessionCleanup.clearLocalOnly();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          return;
        }
        if (status == 'DROP_OTP_VERIFIED' || status == 'PAYMENT_PENDING') {
          _navigated = true;
          _statusPoller?.cancel();
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/ride-payment',
            arguments: {'rideId': rideId},
          );
          return;
        }
        if (status == 'ACCEPTED' ||
            status == 'DRIVER_ASSIGNED' ||
            status == 'DRIVER_ARRIVING' ||
            status == 'DRIVER_ARRIVED' ||
            status == 'ARRIVED' ||
            status == 'ARRIVED_AT_PICKUP' ||
            status == 'OTP_VERIFIED' ||
            status == 'TRIP_STARTED' ||
            status == 'STARTED' ||
            status == 'PICKED_UP' ||
            status == 'IN_TRANSIT' ||
            status == 'IN_PROGRESS' ||
            status == 'DROP_REACHED') {
          _navigated = true;
          _statusPoller?.cancel();
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/ride-tracking',
            arguments: buildRideTrackingArguments(args, statusResponse),
          );
        }
      } catch (_) {
        // keep polling silently while searching
      }
    });
  }

  @override
  void dispose() {
    final a = _rideAcceptedListener;
    final s = _rideStatusListener;
    if (a != null) _socket.offRideAccepted(a);
    if (s != null) _socket.offRideStatusUpdate(s);
    _statusPoller?.cancel();
    _customerLocationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRouteIfNeeded() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final pickupLatLng = resolvePickupLatLng(args);
    final dropoffLatLng = resolveDropLatLng(args);
    if (pickupLatLng == null || dropoffLatLng == null) return;
    if (_routeLoading || _routePoints.isNotEmpty) return;

    setState(() => _routeLoading = true);
    try {
      final pts = await _routeService.routeBetween(pickupLatLng, dropoffLatLng);
      if (!mounted) return;
      setState(() => _routePoints = pts);
    } catch (e) {
      print('OSRM route error: $e');
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  ({String title, String subtitle, bool showSpinner}) _overlayForStatus() {
    switch (rideStatus.toUpperCase()) {
      case 'ACCEPTED':
      case 'DRIVER_ASSIGNED':
        return (
          title: 'Driver assigned',
          subtitle: 'Opening live tracking…',
          showSpinner: true,
        );
      case 'ARRIVED':
      case 'ARRIVED_AT_PICKUP':
        return (
          title: 'Driver has arrived',
          subtitle: 'Opening live tracking…',
          showSpinner: true,
        );
      case 'STARTED':
        return (
          title: 'Ride started',
          subtitle: 'Opening live tracking…',
          showSpinner: true,
        );
      case 'PICKED_UP':
      case 'IN_TRANSIT':
        return (
          title: 'On the way',
          subtitle: 'Opening live tracking…',
          showSpinner: true,
        );
      case 'SEARCHING':
      case 'SEARCHING_DRIVER':
      default:
        return (
          title: 'Searching for nearby drivers',
          subtitle: 'Connecting you in seconds...',
          showSpinner: true,
        );
    }
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _overlayForStatus();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final pickup = args?['pickupAddress']?.toString() ?? args?['pickup']?.toString() ?? 'Pickup';
    final drop = args?['dropoffAddress']?.toString() ?? args?['dropoff']?.toString() ?? 'Drop';
    final taxiType = args?['taxiType']?.toString() ?? 'Small';
    final rideId = args?['rideId']?.toString() ?? '';
    final distanceKm = (args?['distanceKm'] is num) ? (args!['distanceKm'] as num).toDouble() : 17.2;
    final durationMin =
        (args?['durationMin'] is num) ? (args!['durationMin'] as num).toDouble() : 20.0;
    final fare = (args?['fare'] is num) ? (args!['fare'] as num).toDouble() : 432.0;
    final pickupLatLng = resolvePickupLatLng(args);
    final dropoffLatLng = resolveDropLatLng(args);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Map placeholder
            Positioned.fill(
              child: Stack(
                children: [
                  AppMapView(
                pickup: pickupLatLng,
                drop: dropoffLatLng,
                routePoints: _routePoints.isNotEmpty ? _routePoints : null,
                initialCenter: pickupLatLng ?? dropoffLatLng,
                initialZoom: 13.5,
                showRoute: true,
                interactive: true,
              ),
                  if (_routeLoading)
                    Positioned.fill(
                      child: Container(
                        color: AppTheme.background.withValues(alpha: 0.55),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Center loader + text
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: AppTheme.cardDecoration().copyWith(
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (overlay.showSpinner) ...[
                      const SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      overlay.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      overlay.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom summary card
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                decoration: AppTheme.cardDecoration().copyWith(
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_taxi, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            taxiType,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.trip_origin, size: 16, color: AppTheme.success),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              pickup,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              drop,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _infoChip('${distanceKm.toStringAsFixed(1)} km'),
                          const SizedBox(width: 8),
                          _infoChip('${durationMin.toStringAsFixed(0)} min'),
                          const Spacer(),
                          Text(
                            '₹${fare.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          overlay.title == 'Searching for nearby drivers'
                              ? 'Looking for drivers near you…'
                              : overlay.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.danger),
                            foregroundColor: AppTheme.danger,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _cancelling || rideId.isEmpty
                              ? null
                              : () async {
                                  if (_cancelling) return;
                                  setState(() => _cancelling = true);
                                  try {
                                    await RideService.cancelRide(rideId);
                                    await RideSessionCleanup.clearLocalOnly();
                                    if (!mounted) return;
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/home',
                                      (route) => false,
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Cancel failed: $e')),
                                    );
                                  } finally {
                                    if (mounted) setState(() => _cancelling = false);
                                  }
                                },
                          child: Text(
                            _cancelling ? 'CANCELLING...' : 'CANCEL RIDE',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.danger,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
            ),
            // Close button top-left
            Positioned(
              left: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
