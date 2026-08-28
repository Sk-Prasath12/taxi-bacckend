import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/profile_page.dart';
import 'package:taxiapp/notifications_page.dart';

// Widgets
import 'widgets/figma/figma_home_header.dart';
import 'package:taxiapp/services/vehicle_type_service.dart';
import 'widgets/figma/figma_bottom_nav.dart';
import 'widgets/incoming_request/incoming_requ.dart';
import 'widgets/map_background.dart';
import 'package:taxiapp/earnings/earnings_page.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/services/driver_ride_alert.dart';
import 'package:taxiapp/services/active_ride_store.dart';
import 'package:taxiapp/services/driver_ride_listener_service.dart';
import 'package:taxiapp/services/driver_location_service.dart';
import 'package:taxiapp/drive_page/ride_flow/ride_flow_navigator.dart';
import 'package:taxiapp/drive_page/ride_flow/ride_flow_service.dart';
import 'package:taxiapp/services/driver_socket_service.dart';
import 'package:taxiapp/services/driver_approval_watch_service.dart';
import 'package:taxiapp/utils/ride_navigation_utils.dart';

class DashboardPage extends StatefulWidget {
  final AuthService? authService;

  const DashboardPage({super.key, this.authService});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  bool _isOnDuty = false;
  bool _showIncomingRequest = false;
  StreamSubscription<Map<String, dynamic>>? _rideListenerSub;
  StreamSubscription<Map<String, dynamic>>? _rideCancelSub;
  StreamSubscription<Map<String, dynamic>>? _rideTakenSub;
  StreamSubscription<Map<String, dynamic>>? _verificationSub;
  StreamSubscription<void>? _approvalPollSub;
  Map<String, dynamic>? _pendingRide;
  FigmaNavTab _navTab = FigmaNavTab.drive;
  bool _dutyLoading = false;
  bool _approvalHandled = false;
  int _earningsRefreshNonce = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _currentPickup = 'Pickup';
  String _currentDrop = 'Drop-off';

  LatLng _currentPickupLatLng = const LatLng(12.9698, 80.2465);
  LatLng _currentDropLatLng = const LatLng(12.9904, 80.1706);
  double? _currentDistanceKm; // Distance logic

  // Active Ride State
  String? _activePickup;
  String? _activeDrop;
  LatLng? _activePickupLatLng;
  LatLng? _activeDropLatLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreSessionState());
      unawaited(DriverLocationService.instance.getFastFix());
      unawaited(_loadVerificationStatus());
      unawaited(_ensureVerificationSocket());
      _startApprovalWatch();
    });
  }

  void _startApprovalWatch() {
    final auth = AuthService();
    if (auth.canAcceptRides) return;
    DriverApprovalWatchService.instance.start();
    _approvalPollSub ??=
        DriverApprovalWatchService.instance.onApproved.listen((_) => _onDriverApproved());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(DriverApprovalWatchService.instance.checkNow());
    }
  }

  /// Listen for admin approval while driver is still pending (before go-online).
  Future<void> _ensureVerificationSocket() async {
    final auth = AuthService();
    if (auth.token == null || auth.driverId == null || auth.driverId!.isEmpty) return;
    if (auth.canAcceptRides) return;
    final fix = await DriverLocationService.instance.getFastFix();
    final lat = fix?.latitude ?? 12.9700;
    final lng = fix?.longitude ?? 80.2500;
    await DriverSocketService().connect(
      token: auth.token!,
      driverId: auth.driverId!,
      lat: lat,
      lng: lng,
    );
    _verificationSub ??=
        DriverSocketService().verificationStream.listen(_onVerificationUpdate);
  }

  Future<void> _loadVerificationStatus() async {
    await AuthService().refreshProfileFromApi();
    if (!mounted) return;
    final auth = AuthService();
    setState(() {});

    // Do not auto go-online — mandatory Go Online step is on DriverSetupPage / button.
    if (auth.canAcceptRides) {
      return;
    }

    _startApprovalWatch();
    final status = auth.driverVerificationStatus.toUpperCase();
    final driverId = auth.driverId ?? '—';
    final message = status == 'REJECTED'
        ? 'Account rejected by admin. Contact support or re-upload documents.'
        : 'Waiting for admin approval · Driver ID: $driverId';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  Future<void> _restoreSessionState() async {
    await _resumeActiveRideIfNeeded();
    if (!mounted) return;
    final auth = AuthService();
    if (!auth.hasVehicleSetup || !auth.canAcceptRides) return;
    final wasOnDuty = await widget.authService?.wasOnDuty() ?? false;
    if (wasOnDuty && !_isOnDuty) {
      await _handleDutyChange(true);
    }
  }

  Future<void> _resumeActiveRideIfNeeded() async {
    if (RideFlowNavigator.isInFlow) return;
    final stored = await ActiveRideStore.load();
    if (!mounted) return;
    if (stored != null && !ActiveRideStore.isTerminalStatus(stored['status']?.toString())) {
      await RideFlowNavigator.open(context, stored);
      return;
    }
    final token = AuthService().token;
    if (token == null) return;
    final active = await DriverApi.withToken(token).getActiveAssignedRide();
    if (!mounted || active == null) return;
    final status = (active['status'] ?? '').toString();
    if (ActiveRideStore.isTerminalStatus(status)) return;
    final rideId = (active['ride_id'] ?? active['id'] ?? '').toString();
    final payload = {...active, 'id': rideId, 'ride_id': rideId};
    await ActiveRideStore.save(payload);
    if (!mounted) return;
    await RideFlowNavigator.open(context, payload);
  }

  void _showNotificationPopup({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.green),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsPage()),
              );
            },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _approvalPollSub?.cancel();
    DriverApprovalWatchService.instance.stop();
    _rideListenerSub?.cancel();
    _rideCancelSub?.cancel();
    _rideTakenSub?.cancel();
    _verificationSub?.cancel();
    DriverRideAlert.stop();
    if (_isOnDuty) {
      DriverRideListenerService.instance.stop();
    }
    super.dispose();
  }

  Future<void> _handleDutyChange(bool val) async {
    if (val) {
      setState(() {
        _isOnDuty = true;
        _dutyLoading = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (mounted) setState(() => _dutyLoading = false);
      unawaited(_completeGoOnline());
      return;
    }

    setState(() {
      _isOnDuty = false;
      _dutyLoading = false;
    });
    _rideListenerSub?.cancel();
    _rideCancelSub?.cancel();
    _rideTakenSub?.cancel();
    _verificationSub?.cancel();
    DriverRideAlert.stop();
    DriverRideListenerService.instance.stop();
    unawaited(widget.authService?.setWasOnDuty(false));
    setState(() {
      _showIncomingRequest = false;
      _pendingRide = null;
    });
  }

  Future<void> _completeGoOnline() async {
    await AuthService().refreshProfileFromApi();
    if (!mounted) return;
    final auth = AuthService();
    if (!auth.hasVehicleSetup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete vehicle model and number before going online.'),
          backgroundColor: AppColors.warning,
        ),
      );
      setState(() => _isOnDuty = false);
      return;
    }
    if (!auth.canAcceptRides) {
      final status = auth.driverVerificationStatus;
      final msg = status == 'PENDING' || status == 'NOT_SUBMITTED'
          ? 'Waiting for admin to approve your account before you can go online.'
          : 'Your account is not approved yet. Contact admin.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.warning, duration: const Duration(seconds: 6)),
      );
      setState(() => _isOnDuty = false);
      return;
    }

    final ok = await DriverRideListenerService.instance.start();
    if (!mounted) return;

    if (!ok) {
      setState(() => _isOnDuty = false);
      final msg = DriverRideListenerService.instance.lastError ?? 'Could not go online.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
      );
      return;
    }

    _rideListenerSub?.cancel();
    _rideCancelSub?.cancel();
    _rideTakenSub?.cancel();
    _verificationSub?.cancel();
    _rideListenerSub = DriverRideListenerService.instance.incomingRideStream.listen(_onLiveRide);
    _rideCancelSub = DriverRideListenerService.instance.rideCancelledStream.listen(_onRideCancelled);
    _rideTakenSub = DriverSocketService().rideUpdateStream.listen(_onRideTakenByOther);
    _verificationSub = DriverSocketService().verificationStream.listen(_onVerificationUpdate);
    unawaited(widget.authService?.setWasOnDuty(true));
  }

  void _onVerificationUpdate(Map<String, dynamic> payload) {
    final status = (payload['driver_verification_status'] ?? '').toString().toUpperCase();
    final type = (payload['type'] ?? '').toString();
    final approved =
        status == 'APPROVED' ||
        type == 'driver_verification_approved' ||
        payload['is_driver_verified'] == true;
    if (!approved) return;
    unawaited(_onDriverApproved());
  }

  Future<void> _onDriverApproved() async {
    if (_approvalHandled) return;
    await AuthService().refreshProfileFromApi();
    if (!mounted) return;
    setState(() {});
    if (!AuthService().canAcceptRides) return;

    _approvalHandled = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account approved! You can go online and accept rides.'),
        backgroundColor: AppColors.green,
        duration: Duration(seconds: 6),
      ),
    );
    _showNotificationPopup(
      title: 'Admin approved your account',
      message: 'Your driver account is verified. Tap Go Online to start receiving rides.',
    );
    DriverApprovalWatchService.instance.stop();
  }

  void _onRideTakenByOther(Map<String, dynamic> payload) {
    if (!mounted) return;
    if (payload['taken'] != true) return;
    final rideId =
        (payload['ride_id'] ?? payload['rideId'] ?? payload['id'] ?? '').toString();
    if (rideId.isEmpty) return;
    final pendingId =
        (_pendingRide?['id'] ?? _pendingRide?['ride_id'] ?? '').toString();
    if (pendingId != rideId) return;
    DriverRideListenerService.instance.clearAnnounced(rideId);
    DriverRideAlert.stop();
    setState(() {
      _showIncomingRequest = false;
      _pendingRide = null;
    });
  }

  Future<void> _onRideCancelled(Map<String, dynamic> payload) async {
    if (!mounted) return;
    final rideId =
        (payload['ride_id'] ?? payload['rideId'] ?? payload['id'] ?? '').toString();
    if (rideId.isEmpty) return;

    DriverRideListenerService.instance.clearAnnounced(rideId);
    DriverRideAlert.stop();

    final pendingId =
        (_pendingRide?['id'] ?? _pendingRide?['ride_id'] ?? '').toString();
    if (pendingId == rideId) {
      setState(() {
        _showIncomingRequest = false;
        _pendingRide = null;
      });
    }

    final flowRideId =
        (RideFlowService.instance.ride['id'] ?? RideFlowService.instance.ride['ride_id'] ?? '')
            .toString();
    final stored = await ActiveRideStore.load();
    final storedId = (stored?['id'] ?? stored?['ride_id'] ?? '').toString();
    final activeId = flowRideId.isNotEmpty ? flowRideId : storedId;

    final inActiveFlow = RideFlowNavigator.isInFlow && activeId == rideId;
    if (!inActiveFlow) {
      if (pendingId != rideId) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride cancelled by customer')),
        );
      }
      return;
    }

    RideFlowService.instance.disposeFlow();
    RideFlowNavigator.markFlowEnded();
    await ActiveRideStore.clear();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _showIncomingRequest = false;
      _pendingRide = null;
      _activePickup = null;
      _activeDrop = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride cancelled by customer')),
    );
  }

  Future<void> _toggleDutyFromButton() async {
    await _handleDutyChange(!_isOnDuty);
  }

  String get _driverDisplayName {
    final name = widget.authService?.currentUserName;
    if (name != null && name.isNotEmpty) return name;
    final email = widget.authService?.currentUser;
    if (email != null && email.contains('@')) {
      return email.split('@').first.replaceAll('.', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
    }
    return 'Driver';
  }

  String? get _vehicleHeaderLabel {
    final auth = AuthService();
    final type = _vehicleTypeLabel;
    final model = auth.vehicleModel?.trim();
    final plate = auth.vehicleNumber?.trim();
    final parts = <String>[];
    if (type.isNotEmpty) parts.add(type);
    if (model != null && model.isNotEmpty) parts.add(model);
    if (plate != null && plate.isNotEmpty) parts.add(plate);
    if (parts.isEmpty) {
      return auth.hasVehicleSetup ? null : 'Complete vehicle setup to go online';
    }
    return parts.join(' · ');
  }

  Widget? _buildSetupBanner() {
    final auth = AuthService();
    if (auth.canAcceptRides && _isOnDuty) return null;

    final vehicleOk = auth.hasVehicleSetup;
    final approved = auth.canAcceptRides;
    final id = auth.driverId ?? '—';

    String message;
    Color color;
    if (!vehicleOk) {
      message = 'Complete vehicle setup before going online';
      color = AppColors.warning;
    } else if (!approved) {
      message = 'Waiting for admin approval · Driver ID: $id';
      color = AppColors.warning;
    } else if (!_isOnDuty) {
      message = 'Tap GO ONLINE in the header to receive bookings';
      color = AppColors.textSecondary;
    } else {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildLiveStatusBanner() {
    if (!_isOnDuty || !AuthService().canAcceptRides) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.sensors_rounded, color: AppColors.green, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Receiving nearby ride bookings',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _vehicleTypeLabel {
    final raw = AuthService().vehicleType;
    if (raw == null || raw.isEmpty) return '';
    return vehicleDisplayLabel(raw);
  }

  Widget _buildDriveTab() {
    final setupBanner = _buildSetupBanner();
    final liveBanner = _buildLiveStatusBanner();
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: MapBackground()),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FigmaHomeHeader(
                driverName: _driverDisplayName,
                vehicleLabel: _vehicleHeaderLabel,
                isOnDuty: _isOnDuty,
                dutyLoading: _dutyLoading,
                onDutyToggle: _toggleDutyFromButton,
                onNotificationsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              ),
              if (setupBanner != null) setupBanner,
              if (liveBanner != null) liveBanner,
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_showIncomingRequest,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                offset: _showIncomingRequest ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: IncomingRequestPage(
                    passengerName: _pendingRide?['passengerName']?.toString() ?? 'Passenger',
                    pickupLocation: _currentPickup,
                    dropLocation: _currentDrop,
                    distanceKm: (_pendingRide?['nearPickupKm'] as num?)?.toDouble() ?? 0,
                    tripDistanceKm: (_pendingRide?['tripDistanceKm'] as num?)?.toDouble() ??
                        double.tryParse(_pendingRide?['distance']?.toString() ?? '') ??
                        0,
                    estMinutes: int.tryParse(_pendingRide?['duration']?.toString() ?? '') ?? 0,
                    price: (_pendingRide?['fare'] as num?)?.toDouble() ?? 0,
                    paymentMethod: _pendingRide?['paymentMode']?.toString() ?? 'CASH',
                    onAccept: _acceptPendingRide,
                    onDecline: _declinePendingRide,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBody() {
    switch (_navTab) {
      case FigmaNavTab.drive:
        return _buildDriveTab();
      case FigmaNavTab.earnings:
        return EarningsPage(refreshNonce: _earningsRefreshNonce);
      case FigmaNavTab.profile:
        return widget.authService != null
            ? NewProfilePage(authService: widget.authService!)
            : const Center(child: Text('Not signed in'));
    }
  }

  void _onLiveRide(Map<String, dynamic> ride) {
    if (!mounted || !_isOnDuty) return;
    DriverRideAlert.play();
    setState(() {
      _pendingRide = ride;
      _showIncomingRequest = true;
      _currentPickup = ride['pickup']?.toString() ?? _currentPickup;
      _currentDrop = ride['dropoff']?.toString() ?? _currentDrop;
      final plat = ride['pickupLat'];
      final plng = ride['pickupLng'];
      final dlat = ride['dropLat'];
      final dlng = ride['dropLng'];
      if (plat is num && plng is num) {
        _currentPickupLatLng = LatLng(plat.toDouble(), plng.toDouble());
      }
      if (dlat is num && dlng is num) {
        _currentDropLatLng = LatLng(dlat.toDouble(), dlng.toDouble());
      }
      _currentDistanceKm = (ride['nearPickupKm'] as num?)?.toDouble();
    });
    final tripKm = (ride['tripDistanceKm'] as num?)?.toDouble() ??
        double.tryParse(ride['distance']?.toString() ?? '') ??
        0;
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
    final pay = ride['paymentMode']?.toString() ?? 'CASH';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'New ride · Pickup: ${ride['pickup']} → Drop: ${ride['dropoff']} · '
          '${tripKm.toStringAsFixed(1)} km · ₹${fare.toStringAsFixed(0)} · $pay',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => setState(() => _showIncomingRequest = true),
        ),
      ),
    );
  }

  Future<void> _acceptPendingRide() async {
    final ride = _pendingRide;
    if (ride == null) return;
    final rideId = (ride['id'] ?? ride['ride_id'] ?? '').toString();
    if (rideId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid ride id. Wait for the next request.'), backgroundColor: Colors.red),
      );
      return;
    }
    DriverRideAlert.stop();
    setState(() => _showIncomingRequest = false);

    final token = AuthService().token;
    var accepted = false;
    Map<String, dynamic>? serverRide;
    String? errorMessage;

    if (token != null) {
      final result = await DriverApi.withToken(token).acceptRideResult(rideId);
      accepted = result.success;
      serverRide = result.ride;
      errorMessage = result.message;
    }
    if (!accepted) {
      final response = await DriverSocketService().acceptRide(rideId);
      accepted = response['success'] == true ||
          response['ride_id'] != null ||
          response['rideId'] != null;
      if (response['ride'] is Map) {
        serverRide = RideNavigationUtils.ensureCoordinates(
          Map<String, dynamic>.from(response['ride'] as Map),
        );
      }
    }
    if (!accepted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ?? 'Could not accept ride. Ensure admin approved your account and you are online.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _showIncomingRequest = true);
      return;
    }

    DriverRideListenerService.instance.clearAnnounced(rideId);
    final merged = Map<String, dynamic>.from(ride);
    if (serverRide != null) {
      merged.addAll(serverRide);
    }
    if (token != null) {
      final fresh = await DriverApi.withToken(token).getRideById(rideId);
      if (fresh != null) merged.addAll(fresh);
    }
    merged['status'] = (merged['status'] ?? 'accepted').toString();
    merged['id'] = rideId;
    merged['ride_id'] = rideId;
    final acceptedRide = RideNavigationUtils.ensureCoordinates(merged);
    if (!mounted) return;
    RideFlowNavigator.markFlowStarting();
    setState(() {
      _activePickup = ride['pickup']?.toString();
      _activeDrop = ride['dropoff']?.toString();
      final plat = ride['pickupLat'];
      final plng = ride['pickupLng'];
      final dlat = ride['dropLat'];
      final dlng = ride['dropLng'];
      if (plat is num && plng is num) {
        _activePickupLatLng = LatLng(plat.toDouble(), plng.toDouble());
      }
      if (dlat is num && dlng is num) {
        _activeDropLatLng = LatLng(dlat.toDouble(), dlng.toDouble());
      }
      _pendingRide = null;
    });
    await RideFlowNavigator.open(context, acceptedRide);
    if (!mounted) return;
    setState(() => _earningsRefreshNonce++);
    setState(() {
      _activePickup = null;
      _activeDrop = null;
    });
  }

  void _declinePendingRide() {
    final id = _pendingRide?['id']?.toString();
    if (id != null) {
      DriverRideListenerService.instance.clearAnnounced(id);
      final token = AuthService().token;
      if (token != null) {
        unawaited(DriverApi.withToken(token).rejectRideResult(id));
      }
    }
    DriverRideAlert.stop();
    setState(() {
      _showIncomingRequest = false;
      _pendingRide = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.scaffoldDark,
      body: _buildTabBody(),
      bottomNavigationBar: FigmaBottomNav(
        current: _navTab,
        onChanged: (tab) {
          setState(() {
            _navTab = tab;
            if (tab == FigmaNavTab.earnings) _earningsRefreshNonce++;
          });
        },
      ),
    );
  }
}
