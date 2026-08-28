import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../../../config/api_config.dart';
import '../../../domain/services/location_service.dart';
import '../../../domain/services/auth_storage.dart';
import '../../../services/socket_service.dart';
import '../../../domain/app_user.dart';
import '../../../screens/profile/profile_screen.dart';
import '../../../services/customer_auth_manager.dart';
import '../../../services/rating_service.dart';
import '../../../services/ride_service.dart';
import '../../../services/ride_session_cleanup.dart';
import '../../../services/startup_router.dart';
import '../../../utils/device_gps.dart';
import '../../../utils/ride_history_format.dart';
import '../../../widgets/app_map_view.dart';
import '../../../widgets/rating_bottom_sheet.dart';
import 'package:taxi_user/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  bool _hasLocationError = false;
  String? _locationErrorMessage;
  bool _mapReady = false;
  bool _isCenteringLocation = false;
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  StreamSubscription<LocationData>? _locationSubscription;
  List<dynamic> _recentOrders = [];
  bool _isRideHistoryLoading = false;
  String? _rideHistoryError;
  int _selectedIndex = 0;
  bool isRated = false;
  bool _ratingPromptVisible = false;
  bool _postRideRatingChecked = false;
  final Set<String> _ratedRideIds = <String>{};
  String _historyFilter = 'ALL';

  static const Set<String> _activeStatuses = {
    'PENDING_CONFIRMATION',
    'SEARCHING_DRIVER',
    'DRIVER_ASSIGNED',
    'ACCEPTED',
    'ARRIVED_AT_PICKUP',
    'ARRIVED',
    'STARTED',
    'PICKED_UP',
    'IN_TRANSIT',
    'IN_PROGRESS',
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initLocation();
    _reconnectSocketIfNeeded();
    _loadStatsAndHistory();
    unawaited(_resumeActiveRideIfNeeded());
  }

  Future<void> _resumeActiveRideIfNeeded() async {
    try {
      final ride = await RideService.getActiveRide();
      if (!mounted || ride == null) return;
      final dest = StartupRouter.fromActiveRide(ride);
      if (dest.route == '/home') return;
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        dest.route,
        arguments: dest.arguments,
      );
    } catch (e) {
      print('HomeScreen resume active ride: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_postRideRatingChecked) return;
    _postRideRatingChecked = true;
    _tryShowPostRideRating();
  }

  Future<void> _loadUserData() async {
    await CustomerAuthManager.restoreUserFromStorage();
    if (mounted) setState(() {});
  }

  Future<void> _reconnectSocketIfNeeded() async {
    if (!ApiConfig.useBackend) return;
    final token = await AuthStorage.getAccessToken();
    if (token != null &&
        token.isNotEmpty &&
        !SocketService.instance.isConnected) {
      await SocketService.instance.connect();
      SocketService.instance.joinCustomerRoom();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationService.stopTracking();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    _locationSubscription = _locationService.statusStream.listen((data) {
      if (mounted) {
        setState(() {
          if (data.position != null) {
            _currentLocation = data.position;
          }
          _isLoadingLocation = data.state == LocationState.loading;
          _hasLocationError = data.state == LocationState.error ||
              data.state == LocationState.permissionDenied;
          _locationErrorMessage = data.errorMessage;
        });

        if (_currentLocation != null && _mapReady) {
          _mapController.move(_currentLocation!, _mapController.camera.zoom);
        }
      }
    });

    await _locationService.getCurrentLocation();
    _locationService.startTracking();
  }

  Future<void> _loadStatsAndHistory() async {
    if (mounted) {
      setState(() {
        _isRideHistoryLoading = true;
        _rideHistoryError = null;
      });
    }
    if (!ApiConfig.useBackend) {
      final localHistory = await AuthStorage.getHistory();
      if (mounted) {
        setState(() {
          _recentOrders = localHistory;
          _isRideHistoryLoading = false;
        });
      }
      return;
    }
    List<dynamic> orders = [];
    String? historyError;

    try {
      orders = await RideService.getRideHistory();
      print("RIDES DATA: $orders");
    } catch (e) {
      print("RIDES ERROR: $e");
      historyError = 'Failed to load rides';
    }

    if (mounted) {
      setState(() {
        _recentOrders = orders;
        _rideHistoryError = historyError;
        _isRideHistoryLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _locationService.getCurrentLocation();
    await _loadStatsAndHistory();
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_isCenteringLocation) return;
    setState(() => _isCenteringLocation = true);
    try {
      final blocked = await DeviceGps.ensureReady();
      if (blocked != null) throw Exception(blocked);

      final latLng = await DeviceGps.currentLatLng();
      if (!mounted) return;

      setState(() {
        _currentLocation = latLng;
        _isLoadingLocation = false;
        _hasLocationError = false;
        _locationErrorMessage = null;
      });

      if (_mapReady) {
        _mapController.move(latLng, 16);
      }

      await _locationService.getCurrentLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasLocationError = true;
        _locationErrorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationErrorMessage ?? 'Could not get location'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCenteringLocation = false);
    }
  }

  Future<void> _onBookRidePressed() async {
    await RideSessionCleanup.resetForNewSession();
    if (!mounted) return;
    final loc = _currentLocation;
    Navigator.pushNamed(
      context,
      '/pickup-location',
      arguments: {
        'mode': 'pickup',
        if (loc != null) 'initialLatLng': loc,
      },
    );
  }

  Future<void> showRating(
      BuildContext context, String rideId, String token) async {
    if (_ratingPromptVisible) return;
    _ratingPromptVisible = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingBottomSheet(
        onSubmit: (rating, review) async {
          await RatingService.submitRating(
            token: token,
            rideId: rideId,
            rating: rating,
            review: review,
          );
          if (!mounted) return;
          setState(() {
            isRated = true;
            _ratedRideIds.add(rideId);
          });
        },
      ),
    );
    _ratingPromptVisible = false;
  }

  Future<void> _tryShowPostRideRating() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final lastRideStatus =
        (args?['lastRideStatus']?.toString() ?? '').toUpperCase();
    final rideId = args?['rideId']?.toString() ?? '';
    if (lastRideStatus != 'COMPLETED' ||
        rideId.isEmpty ||
        isRated ||
        _ratedRideIds.contains(rideId)) {
      return;
    }
    final token = await AuthStorage.getAccessToken();
    if (!mounted || token == null || token.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted || isRated || _ratedRideIds.contains(rideId)) return;
      try {
        await showRating(context, rideId, token);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit rating: $e')),
        );
      }
    });
  }

  String _userInitials() {
    final name = AppUser.displayName.trim();
    if (name.isEmpty) return 'U';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _timeAgo(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> get _recentForHome {
    final list = <Map<String, dynamic>>[];
    for (final o in _recentOrders.take(10)) {
      if (o is Map) list.add(Map<String, dynamic>.from(o));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _selectedIndex == 0 ? _buildHomeLayout() : _buildBody(),
      bottomNavigationBar:
          _selectedIndex == 0 ? _buildHomeBottomChrome() : _buildBottomNav(),
    );
  }

  /// Compact tab bar only — Book Ride lives in the map bottom sheet.
  Widget _buildHomeBottomChrome() {
    return ColoredBox(
      color: AppTheme.background,
      child: SafeArea(
        top: false,
        child: _buildBottomNavBarRow(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return ColoredBox(
      color: AppTheme.background,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: _buildBottomNavBarRow(),
      ),
    );
  }

  Widget _buildBottomNavBarRow() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.home_rounded, 'Home'),
            _navItem(1, Icons.history_rounded, 'Trips'),
            _navItem(3, Icons.person_outline_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? AppTheme.primary : AppTheme.textMuted, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? AppTheme.primary : AppTheme.textMuted,
                fontSize: 11,
                height: 1.1,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(
              height: 6,
              child: Center(
                child: active
                    ? Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeLayout() {
    final bottomNavH = 52.0 + MediaQuery.paddingOf(context).bottom;
    // Collapsed ~ map-first; half & full for Book Ride / Trip History / recent.
    const collapsed = 0.20;
    const half = 0.42;
    const full = 0.72;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _buildMapLayer()),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 16,
          right: 16,
          child: _buildTopBar(),
        ),
        if (_isLoadingLocation)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 72,
            left: 0,
            right: 0,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: MediaQuery.sizeOf(context).height * collapsed + 12,
          child: FloatingActionButton.small(
            heroTag: 'home_my_location',
            backgroundColor: AppTheme.primary,
            tooltip: 'My location',
            onPressed: _isCenteringLocation ? null : _centerOnCurrentLocation,
            child: _isCenteringLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.my_location_rounded, color: AppTheme.onPrimary),
          ),
        ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (_) => false,
          child: DraggableScrollableSheet(
            initialChildSize: collapsed,
            minChildSize: collapsed,
            maxChildSize: full,
            snap: true,
            snapSizes: const [collapsed, half, full],
            builder: (context, scrollController) {
              return _buildHomeBottomSheet(scrollController);
            },
          ),
        ),
        // Keep map tappable above collapsed sheet margin — sheet handles its own drag.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: bottomNavH,
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildHomeBottomSheet(ScrollController scrollController) {
    final firstName = AppUser.displayName.split(' ').first;

    return Container(
      decoration: AppTheme.sheetDecoration().copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        onRefresh: _onRefresh,
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            _buildHomePanelHeader(firstName),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _onBookRidePressed,
                  icon: const Icon(Icons.local_taxi_rounded),
                  label: const Text(
                    'Book a Ride',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            ..._recentRideSectionChildren(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePanelHeader(String firstName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Swipe up for Book Ride & trips',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_greeting()}, $firstName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _quickDestCard(
                  icon: Icons.local_taxi_rounded,
                  iconColor: AppTheme.primary,
                  title: 'Book ride',
                  subtitle: 'Pickup → Drop',
                  onTap: _onBookRidePressed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickDestCard(
                  icon: Icons.history_rounded,
                  iconColor: AppTheme.primaryLight,
                  title: 'Trip history',
                  subtitle: 'Past rides',
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'RECENT',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (_recentOrders.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _recentRideSectionChildren() {
    if (_isRideHistoryLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
          ),
        ),
      ];
    }

    if (_rideHistoryError != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Text(
            _rideHistoryError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger, fontSize: 13),
          ),
        ),
      ];
    }

    if (_recentForHome.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Text(
            'No recent rides yet',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8)),
          ),
        ),
      ];
    }

    return [
      for (final ride in _recentForHome)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildRecentItem(ride),
        ),
    ];
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedIndex = 3),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary,
            child: Text(
              _userInitials(),
              style: const TextStyle(
                color: AppTheme.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _onBookRidePressed,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Where are you going?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickDestCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItem(Map<String, dynamic> m) {
    final drop = RideHistoryFormat.addressFrom(m, nestedKey: 'drop');
    final fare = RideHistoryFormat.fareAmount(m);
    final createdAt = m['createdAt']?.toString() ?? m['created_at']?.toString();
    final rideId = RideHistoryFormat.rideId(m);
    final driver = RideHistoryFormat.driverName(m);

    return GestureDetector(
      onTap: rideId.isEmpty
          ? null
          : () => Navigator.pushNamed(
                context,
                '/ride-history-detail',
                arguments: {'rideId': rideId},
              ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.location_on_rounded, color: Color(0xFFE879A8), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drop,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    [
                      _timeAgo(createdAt),
                      if (driver != null) driver,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '₹${fare.toStringAsFixed(0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLayer() {
    final center = _currentLocation ?? const LatLng(13.0827, 80.2707);

    return AppMapView(
      mapController: _mapController,
      customer: _currentLocation,
      initialCenter: center,
      initialZoom: 14,
      showRoute: false,
      interactive: true,
      onMapReady: () {
        if (mounted) setState(() => _mapReady = true);
        if (_currentLocation != null) {
          _mapController.move(_currentLocation!, _mapController.camera.zoom);
        }
      },
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return _buildRideHistoryContent();
      case 3:
        return _buildProfileContent();
      default:
        return _buildHomeLayout();
    }
  }

  String _lastRideHint({required bool isPickup}) {
    for (final o in _recentOrders) {
      if (o is! Map) continue;
      final m = Map<String, dynamic>.from(o);
      if (RideHistoryFormat.status(m) != 'COMPLETED') continue;
      final addr = RideHistoryFormat.addressFrom(
        m,
        nestedKey: isPickup ? 'pickup' : 'drop',
      );
      if (addr != 'Pickup location' && addr != 'Drop location') {
        return addr.length > 28 ? '${addr.substring(0, 28)}…' : addr;
      }
    }
    return isPickup ? 'Choose pickup on map' : 'See past destinations';
  }

  List<Map<String, dynamic>> get _filteredHistoryMaps {
    final list = <Map<String, dynamic>>[];
    for (final o in _recentOrders) {
      if (o is! Map) continue;
      final m = Map<String, dynamic>.from(o);
      final status = (m['status']?.toString() ?? '').toUpperCase();
      switch (_historyFilter) {
        case 'ACTIVE':
          if (_activeStatuses.contains(status)) list.add(m);
          break;
        case 'COMPLETED':
          if (status == 'COMPLETED') list.add(m);
          break;
        case 'CANCELLED':
          if (status == 'CANCELLED') list.add(m);
          break;
        default:
          list.add(m);
      }
    }
    return list;
  }

  Widget _historyFilterChip(String label, String value) {
    final selected = _historyFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _historyFilter = value),
        selectedColor: AppTheme.primary,
        checkmarkColor: AppTheme.ink,
        backgroundColor: AppTheme.surfaceLight,
        labelStyle: TextStyle(
          color: selected ? AppTheme.ink : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
      ),
    );
  }

  Widget _buildRideHistoryContent() {
    if (_isRideHistoryLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
      );
    }
    if (_rideHistoryError != null) {
      return Center(
        child: Text(_rideHistoryError!, style: const TextStyle(color: AppTheme.textSecondary)),
      );
    }
    final filtered = _filteredHistoryMaps;
    final summary = RideHistoryFormat.overallSummary(filtered);
    final groups = RideHistoryFormat.groupByDay(filtered);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trips',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _tripStatChip('${summary.totalTrips} trips', Icons.local_taxi_outlined),
                    const SizedBox(width: 8),
                    _tripStatChip(
                      '₹${summary.totalSpent.toStringAsFixed(0)} spent',
                      Icons.payments_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              _historyFilterChip('All', 'ALL'),
              _historyFilterChip('Active', 'ACTIVE'),
              _historyFilterChip('Completed', 'COMPLETED'),
              _historyFilterChip('Cancelled', 'CANCELLED'),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.history_rounded, size: 64, color: AppTheme.textMuted),
                      SizedBox(height: 12),
                      Text('No rides in this category', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
                  onRefresh: _onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final group in groups) ...[
                        _buildDayHeader(group.day, group.rides),
                        for (final ride in group.rides) _buildHistoryItem(ride),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProfileContent() {
    return const ProfileScreen(embedInShell: true);
  }

  Widget _tripStatChip(String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(DateTime day, List<Map<String, dynamic>> rides) {
    final summary = RideHistoryFormat.daySummary(rides);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              RideHistoryFormat.formatDayHeader(day),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            '${summary.trips} · ₹${summary.spent.toStringAsFixed(0)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatRideDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '—';
    try {
      final dateTime = DateTime.parse(rawDate).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } catch (_) {
      return rawDate;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> m) {
    final rideId = RideHistoryFormat.rideId(m);
    final pickup = RideHistoryFormat.addressFrom(m, nestedKey: 'pickup');
    final drop = RideHistoryFormat.addressFrom(m, nestedKey: 'drop');
    final status = RideHistoryFormat.status(m);
    final fare = RideHistoryFormat.fareAmount(m);
    final distance = m['distance_km'] ?? m['distanceKm'] ?? m['distance'] ?? '—';
    final duration = m['duration_min'] ?? m['durationMin'] ?? m['duration'] ?? '—';
    final paymentMode =
        (m['paymentMode'] ?? m['payment_mode'] ?? '—').toString().toUpperCase();
    final paymentStatus =
        (m['paymentStatus'] ?? m['payment_status'] ?? 'PENDING')
            .toString()
            .toUpperCase();
    final createdAt = RideHistoryFormat.formatDateTime(m);
    final driverName = RideHistoryFormat.driverName(m);
    final driverPhone = RideHistoryFormat.driverPhone(m);
    final driverStatus = m['driver'] is Map
        ? (m['driver'] as Map)['status']?.toString().toUpperCase()
        : null;
    final otp = m['otp']?.toString() ?? '—';
    final otpVerified = m['otpVerified'] == true || m['otp_verified'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: rideId.isEmpty
          ? null
          : () => Navigator.pushNamed(
                context,
                '/ride-history-detail',
                arguments: {'rideId': rideId},
              ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${fare.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.trip_origin, size: 14, color: AppTheme.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pickup,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      drop,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                createdAt,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$distance km',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$duration min',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payment: $paymentMode',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      paymentStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (driverName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Driver: $driverName${driverPhone != null ? ' · $driverPhone' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ] else if (status != 'SEARCHING_DRIVER' && status != 'CANCELLED') ...[
                const SizedBox(height: 8),
                const Text(
                  'Driver: Not assigned yet',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'OTP: $otp   Verified: ${otpVerified ? 'Yes' : 'No'}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (rideId.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'View details',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ],
        ),
      ),
    );
  }
}
