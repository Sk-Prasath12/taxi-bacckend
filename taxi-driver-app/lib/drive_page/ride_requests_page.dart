import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/services/driver_ride_alert.dart';
import 'package:taxiapp/services/driver_ride_listener_service.dart';
import 'package:taxiapp/drive_page/ride_flow/ride_flow_navigator.dart';
import 'package:taxiapp/services/driver_socket_service.dart';
import 'package:taxiapp/utils/ride_navigation_utils.dart';

class RideRequestsPage extends StatefulWidget {
  const RideRequestsPage({super.key});

  @override
  State<RideRequestsPage> createState() => _RideRequestsPageState();
}

class _RideRequestsPageState extends State<RideRequestsPage> {
  /// Near Chennai test pickup (BSR Mall) when GPS is unavailable (e.g. web).
  static const double _fallbackLat = 12.9497795;
  static const double _fallbackLng = 80.2404968;

  final DriverSocketService _socketService = DriverSocketService();
  final List<Map<String, dynamic>> _rideRequests = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _online = false;
  double? _driverLat;
  double? _driverLng;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _rideNewSub;
  StreamSubscription<Map<String, dynamic>>? _rideUpdateSub;

  @override
  void initState() {
    super.initState();
    _initializeRealtime();
  }

  Future<void> _initializeRealtime() async {
    if (!DriverRideListenerService.instance.isRunning) {
      await DriverRideListenerService.instance.start();
    }
    final pos = await DriverRideListenerService.instance.currentPosition();
    if (pos != null) {
      _driverLat = pos.latitude;
      _driverLng = pos.longitude;
    }

    _rideNewSub = DriverRideListenerService.instance.incomingRideStream.listen(_onRideNew);
    _rideUpdateSub = DriverSocketService().rideUpdateStream.listen(_onRideUpdate);

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollIncomingRides());
    await _pollIncomingRides();

    final err = DriverRideListenerService.instance.lastError;
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.warning, duration: const Duration(seconds: 6)),
      );
    }
    if (!mounted) return;
    setState(() {
      _online = DriverRideListenerService.instance.isRunning;
      _loading = false;
    });
  }

  Future<void> _pollIncomingRides() async {
    final token = AuthService().token;
    if (token == null) return;
    final result = await DriverApi.withToken(token).fetchIncomingRides(
      lat: _driverLat,
      lng: _driverLng,
    );
    final incoming = result.rides;
    if (!mounted) return;
    final filtered = incoming.where((ride) {
      final status = (ride['status']?.toString() ?? '').toUpperCase();
      return status == 'REQUESTED' ||
          status == 'SEARCHING_DRIVER' ||
          status == 'PENDING_CONFIRMATION';
    }).map(_normalizeApiRide).toList();
    setState(() {
      for (final ride in filtered) {
        _upsertRide(ride);
      }
      _sortByPickupDistance();
    });
  }

  void _upsertRide(Map<String, dynamic> ride) {
    final id = ride['id'].toString();
    final index = _rideRequests.indexWhere((r) => r['id'].toString() == id);
    if (index >= 0) {
      _rideRequests[index] = {..._rideRequests[index], ...ride};
    } else {
      _rideRequests.insert(0, ride);
    }
  }

  void _sortByPickupDistance() {
    _rideRequests.sort((a, b) {
      final da = (a['nearPickupKm'] as num?)?.toDouble() ?? 9999;
      final db = (b['nearPickupKm'] as num?)?.toDouble() ?? 9999;
      return da.compareTo(db);
    });
  }

  double? _distanceKmToPickup(Map<String, dynamic> ride) {
    if (_driverLat == null || _driverLng == null) return null;
    final lat = ride['pickupLat'];
    final lng = ride['pickupLng'];
    if (lat == null || lng == null) return null;
    final meters = Geolocator.distanceBetween(
      _driverLat!,
      _driverLng!,
      (lat as num).toDouble(),
      (lng as num).toDouble(),
    );
    return meters / 1000;
  }

  Map<String, dynamic> _normalizeApiRide(Map<String, dynamic> ride) {
    final pickup = ride['pickup'];
    final drop = ride['drop'];
    return <String, dynamic>{
      'id': (ride['id'] ?? ride['_id'] ?? ride['ride_id']).toString(),
      'passengerName': ride['customer_name'] ?? ride['passengerName'] ?? 'Passenger',
      'pickup': _fmtLocation(pickup),
      'dropoff': _fmtLocation(drop),
      'distance': (ride['distance_km'] ?? ride['distance'] ?? '0').toString(),
      'duration': ride['duration_min']?.toString() ?? 'N/A',
      'fare': (ride['fare'] as num?)?.toDouble() ?? 0.0,
      'status': (ride['status'] ?? 'SEARCHING_DRIVER').toString().toUpperCase(),
      'time': DateTime.now(),
      'rating': 5.0,
      'trips': 0,
      'pickupLat': pickup is Map ? pickup['lat'] : null,
      'pickupLng': pickup is Map ? pickup['lng'] : null,
      'dropLat': drop is Map ? drop['lat'] : null,
      'dropLng': drop is Map ? drop['lng'] : null,
      'nearPickupKm': _distanceKmToPickup({
        'pickupLat': pickup is Map ? pickup['lat'] : null,
        'pickupLng': pickup is Map ? pickup['lng'] : null,
      }),
    };
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _rideNewSub?.cancel();
    _rideUpdateSub?.cancel();
    DriverRideAlert.stop();
    super.dispose();
  }

  void _onRideNew(Map<String, dynamic> payload) {
    if (!mounted) return;
    DriverRideAlert.play();
    setState(() {
      _upsertRide(_socketRideToUiRide(payload));
      _sortByPickupDistance();
    });
  }

  void _onRideUpdate(Map<String, dynamic> payload) {
    if (!mounted) return;
    final ride = payload['ride'] is Map<String, dynamic> ? payload['ride'] as Map<String, dynamic> : payload;
    final rideId = (ride['rideId'] ?? ride['ride_id'] ?? ride['id'] ?? '').toString();
    if (rideId.isEmpty) return;

    setState(() {
      _rideRequests.removeWhere((item) => item['id'].toString() == rideId);
    });
  }

  Map<String, dynamic> _socketRideToUiRide(Map<String, dynamic> ride) {
    final ui = <String, dynamic>{
      'id': (ride['rideId'] ?? ride['ride_id'] ?? ride['id']).toString(),
      'passengerName': ride['customerName'] ?? 'Passenger',
      'pickup': _fmtLocation(ride['pickup']),
      'dropoff': _fmtLocation(ride['drop'] ?? ride['dropoff']),
      'distance': (ride['distance_km'] ?? ride['distance'] ?? '0').toString(),
      'duration': 'N/A',
      'fare': (ride['fare'] as num?)?.toDouble() ?? 0.0,
      'status': (ride['status'] ?? 'SEARCHING_DRIVER').toString().toUpperCase(),
      'time': DateTime.now(),
      'rating': 5.0,
      'trips': 0,
      'pickupLat': ride['pickup']?['lat'],
      'pickupLng': ride['pickup']?['lng'],
      'dropLat': ride['drop']?['lat'],
      'dropLng': ride['drop']?['lng'],
    };
    final socketKm = ride['distance_km'];
    ui['nearPickupKm'] = socketKm is num
        ? socketKm.toDouble()
        : _distanceKmToPickup(ui);
    return ui;
  }

  String _fmtLocation(dynamic loc) {
    if (loc is Map) {
      final address = loc['address']?.toString();
      if (address != null && address.isNotEmpty) return address;
      return '${loc['lat']}, ${loc['lng']}';
    }
    return loc?.toString() ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Requests'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: _online ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(_online ? 'Online' : 'Offline', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rideRequests.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rideRequests.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _buildRideRequestCard(_rideRequests[index]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_car,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No Ride Requests Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ride requests will appear here when you\'re online',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initializeRealtime,
            icon: const Icon(Icons.power),
            label: const Text('Go Online'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideRequestCard(Map<String, dynamic> ride) {
    final dynamic rawTime = ride['time'];
    final DateTime rideTime = rawTime is DateTime
        ? rawTime
        : DateTime.tryParse(rawTime?.toString() ?? '') ?? DateTime.now();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passenger Info
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                radius: 24,
                child: Text(
                  (ride['passengerName'] as String)[0],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride['passengerName'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: AppColors.green),
                        const SizedBox(width: 4),
                        Text(
                          '${ride['rating']} • ${ride['trips']} trips',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (ride['nearPickupKm'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(ride['nearPickupKm'] as num).toStringAsFixed(1)} km away',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${rideTime.difference(DateTime.now()).inMinutes.abs()}m ago',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Route
          _buildRouteItem(
            icon: Icons.my_location,
            color: Colors.green,
            label: 'Pickup',
            value: ride['pickup'] as String,
          ),
          const SizedBox(height: 12),
          _buildRouteItem(
            icon: Icons.flag,
            color: Colors.red,
            label: 'Drop-off',
            value: ride['dropoff'] as String,
          ),
          const SizedBox(height: 20),

          // Trip Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTripDetail(
                  icon: Icons.straighten,
                  value: ride['distance'] as String,
                  label: 'Distance',
                ),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildTripDetail(
                  icon: Icons.timer,
                  value: ride['duration'] as String,
                  label: 'Duration',
                ),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildTripDetail(
                  icon: Icons.attach_money,
                  value: '₹${ride['fare'].toStringAsFixed(0)}',
                  label: 'Fare',
                  isPrimary: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _rejectRide(ride);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    _acceptRide(ride);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Accept Ride',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripDetail({
    required IconData icon,
    required String value,
    required String label,
    bool isPrimary = false,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: isPrimary ? Theme.of(context).primaryColor : AppColors.textSecondary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isPrimary ? Theme.of(context).primaryColor : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _acceptRide(Map<String, dynamic> ride) async {
    DriverRideAlert.stop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Accepting Ride'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Connecting to ${ride['passengerName']}...'),
          ],
        ),
      ),
    );

    final token = AuthService().token;
    final rideId = ride['id'].toString();
    var accepted = false;
    if (token != null) {
      accepted = await DriverApi.withToken(token).acceptRide(rideId);
    }
    if (!accepted) {
      final response = await _socketService.acceptRide(rideId);
      accepted = response['success'] == true ||
          response['ride_id'] != null ||
          response['status'] == 'DRIVER_ASSIGNED';
    }
    if (!mounted) return;
    Navigator.pop(context);

    if (!accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to accept ride. Ask admin to approve your account and stay online.'),
          backgroundColor: AppColors.green,
        ),
      );
      return;
    }

    setState(() {
      _rideRequests.removeWhere((r) => r['id'] == ride['id']);
    });

    final acceptedRide = RideNavigationUtils.ensureCoordinates(
      Map<String, dynamic>.from(ride)
        ..['status'] = 'DRIVER_ASSIGNED'
        ..['id'] = rideId
        ..['ride_id'] = rideId,
    );

    if (!mounted) return;
    RideFlowNavigator.markFlowStarting();
    await RideFlowNavigator.open(context, acceptedRide);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ride accepted! Navigating to passenger...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _rejectRide(Map<String, dynamic> ride) {
    DriverRideAlert.stop();
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why are you declining this ride?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildReasonOption('Too far from pickup', ride),
            _buildReasonOption('Low fare', ride),
            _buildReasonOption('Traffic conditions', ride),
            _buildReasonOption('Other', ride),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonOption(String reason, Map<String, dynamic> ride) {
    return ListTile(
      leading: const Icon(Icons.radio_button_unchecked),
      title: Text(reason),
      onTap: () async {
        Navigator.pop(context);
        final rideId = (ride['id'] ?? ride['ride_id'] ?? '').toString();
        final token = AuthService().token;
        if (token != null && rideId.isNotEmpty) {
          await DriverApi.withToken(token).rejectRideResult(rideId);
          DriverRideListenerService.instance.clearAnnounced(rideId);
        }
        if (!mounted) return;
        setState(() {
          _rideRequests.removeWhere(
            (r) => (r['id'] ?? r['ride_id'] ?? '').toString() == rideId,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride declined: $reason')),
        );
      },
    );
  }

}
