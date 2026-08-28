import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/booking_draft_store.dart';
import '../../services/location_service.dart';
import '../../utils/chennai_area.dart';
import '../../utils/device_gps.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map_view.dart';

class SearchLocationScreen extends StatefulWidget {
  const SearchLocationScreen({super.key});

  @override
  State<SearchLocationScreen> createState() => _SearchLocationScreenState();
}

class _SearchLocationScreenState extends State<SearchLocationScreen> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropFocus = FocusNode();
  final _nominatim = NominatimLocationService();
  final MapController _mapController = MapController();

  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;
  bool _isLocatingCurrent = false;
  bool _mapReady = false;
  String? _error;
  bool _isPickupActive = true;

  LatLng? _mapCenter;
  double? pickupLat;
  double? pickupLng;
  double? dropLat;
  double? dropLng;
  String? pickupAddress;
  String? dropAddress;

  StreamSubscription<Position>? _positionSub;
  Timer? _addressDebounce;
  final ValueNotifier<LatLng?> _customerGps = ValueNotifier<LatLng?>(null);
  bool _pickupTracksGps = true;
  bool _pickupManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _pickupFocus.addListener(_onPickupFocus);
    _dropFocus.addListener(_onDropFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _startGpsStream();
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      final initialPickup = args?['initialPickupLatLng'];
      if (initialPickup is LatLng) {
        final pickup = ChennaiArea.inServiceOrFallback(initialPickup);
        pickupLat = pickup.latitude;
        pickupLng = pickup.longitude;
        _mapCenter = pickup;
        _customerGps.value = pickup;
        _pickupTracksGps = args?['fromHomeGps'] == true;
        _pickupManuallyEdited = args?['fromHomeGps'] != true;
        pickupAddress = await _addressFor(pickup.latitude, pickup.longitude);
        _pickupController.text = pickupAddress ?? '';
        _isPickupActive = false;
        _moveMap(pickup, zoom: 16);
        if (mounted) setState(() {});
      } else {
        await _centerMapOnDeviceGps();
        await _useCurrentLocation(silent: true);
      }
    });
  }

  void _onPickupFocus() {
    if (_pickupFocus.hasFocus) {
      setState(() => _isPickupActive = true);
    }
  }

  void _onDropFocus() {
    if (_dropFocus.hasFocus) {
      setState(() => _isPickupActive = false);
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    _debounce?.cancel();
    _addressDebounce?.cancel();
    _positionSub?.cancel();
    _customerGps.dispose();
    super.dispose();
  }

  Future<void> _startGpsStream() async {
    final blocked = await DeviceGps.ensureReady();
    if (blocked != null || !mounted) return;

    _positionSub?.cancel();
    _positionSub = DeviceGps.positionStream().listen((position) {
      if (!mounted) return;
      // Once pickup is chosen (or drop is set), never overwrite with device GPS.
      if (!_pickupTracksGps || _pickupManuallyEdited || dropLat != null) {
        final latLng = ChennaiArea.inServiceOrFallback(
          LatLng(position.latitude, position.longitude),
        );
        _customerGps.value = latLng;
        return;
      }
      final latLng = ChennaiArea.inServiceOrFallback(
        LatLng(position.latitude, position.longitude),
      );
      _customerGps.value = latLng;

      pickupLat = latLng.latitude;
      pickupLng = latLng.longitude;
      pickupAddress ??=
          '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
      _mapCenter = latLng;
      _schedulePickupAddressRefresh(latLng.latitude, latLng.longitude);
      setState(() {});
    });
  }

  void _schedulePickupAddressRefresh(double lat, double lng) {
    _addressDebounce?.cancel();
    _addressDebounce = Timer(const Duration(milliseconds: 1200), () async {
      if (!mounted || !_pickupTracksGps || _pickupManuallyEdited) return;
      final address = await _addressFor(lat, lng);
      if (!mounted || !_pickupTracksGps || _pickupManuallyEdited) return;
      pickupAddress = address;
      _pickupController.text = address;
      setState(() {});
    });
  }

  Future<void> _centerMapOnDeviceGps() async {
    try {
      final blocked = await DeviceGps.ensureReady();
      if (blocked != null) return;
      final latLng = await DeviceGps.currentLatLng();
      if (!mounted) return;
      _mapCenter = latLng;
      _customerGps.value = latLng;
      _moveMap(latLng, zoom: 15);
      setState(() {});
    } catch (_) {}
  }

  void _moveMap(LatLng target, {double zoom = 15}) {
    if (!_mapReady) return;
    try {
      _mapController.move(target, zoom);
    } catch (_) {}
  }

  Future<String> _addressFor(double lat, double lng) async {
    try {
      final fromNominatim = await _nominatim.reverseGeocode(lat, lng);
      if (fromNominatim != null && fromNominatim.trim().isNotEmpty) {
        return fromNominatim.trim();
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    if (_isLocatingCurrent) return;
    setState(() {
      _isLocatingCurrent = true;
      if (!silent) _error = null;
    });

    try {
      final blocked = await DeviceGps.ensureReady();
      if (blocked != null) throw Exception(blocked);

      final latLng = await DeviceGps.currentLatLng();
      final address = await _addressFor(latLng.latitude, latLng.longitude);
      if (!mounted) return;

      final wasPickupField = _isPickupActive;
      // GPS button / auto-locate sets the pin once, then freezes it so live GPS
      // cannot change the pickup used for nearby-driver matching.
      _applyGpsToActiveField(
        lat: latLng.latitude,
        lng: latLng.longitude,
        address: address,
      );

      _mapCenter = latLng;
      _customerGps.value = latLng;
      _moveMap(latLng, zoom: 16);

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasPickupField
                  ? 'Pickup set from GPS. Now choose drop location.'
                  : 'Drop set from GPS.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error = msg);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingCurrent = false);
    }
  }

  void _applyGpsToActiveField({
    required double lat,
    required double lng,
    required String address,
  }) {
    if (_isPickupActive) {
      pickupLat = lat;
      pickupLng = lng;
      pickupAddress = address;
      _pickupController.text = address;
      // GPS button intentionally sets pickup — freeze that pin afterwards.
      _pickupTracksGps = false;
      _pickupManuallyEdited = true;
      _isPickupActive = false;
      _dropFocus.requestFocus();
    } else {
      dropLat = lat;
      dropLng = lng;
      dropAddress = address;
      _dropController.text = address;
      _pickupTracksGps = false;
      _pickupManuallyEdited = true;
    }
    setState(() {});
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().length < 3) {
        if (!mounted) return;
        setState(() {
          _suggestions = [];
          _isLoading = false;
          _error = null;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final results = await _nominatim.searchPlaces(query);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _suggestions = [];
          _error = 'Failed to fetch locations';
        });
      }
    });
  }

  void _applySearchSelection({
    required double lat,
    required double lng,
    required String address,
  }) {
    if (!ChennaiArea.contains(lat, lng)) {
      setState(() => _error = ChennaiArea.outOfAreaMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChennaiArea.outOfAreaMessage)),
      );
      return;
    }
    final selectedLatLng = LatLng(lat, lng);
    if (_isPickupActive) {
      pickupLat = lat;
      pickupLng = lng;
      pickupAddress = address;
      _pickupController.text = address;
      _pickupTracksGps = false;
      _pickupManuallyEdited = true;
      _isPickupActive = false;
      _suggestions = [];
      _dropFocus.requestFocus();
    } else {
      dropLat = lat;
      dropLng = lng;
      dropAddress = address;
      _dropController.text = address;
      _suggestions = [];
      // Freeze pickup once drop is chosen so GPS cannot change matching location.
      _pickupTracksGps = false;
      _pickupManuallyEdited = true;
    }
    _mapCenter = selectedLatLng;
    _moveMap(selectedLatLng, zoom: 15);
    setState(() {});
  }

  void _clearLocations() {
    setState(() {
      pickupLat = null;
      pickupLng = null;
      dropLat = null;
      dropLng = null;
      pickupAddress = null;
      dropAddress = null;
      _pickupController.clear();
      _dropController.clear();
      _suggestions = [];
      _error = null;
      _isLoading = false;
      _isPickupActive = true;
      _pickupTracksGps = true;
      _pickupManuallyEdited = false;
    });
    _pickupFocus.requestFocus();
    _centerMapOnDeviceGps();
  }

  String get _currentLocationLabel {
    if (_isPickupActive) {
      return pickupLat == null ? 'Use GPS for Pickup' : 'Update Pickup (GPS)';
    }
    return dropLat == null ? 'Use GPS for Drop' : 'Update Drop (GPS)';
  }

  bool get _canConfirm => pickupLat != null && dropLat != null;

  @override
  Widget build(BuildContext context) {
    final mapCenter = _mapCenter ?? _customerGps.value ?? const LatLng(13.0827, 80.2707);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AppMapView(
                mapController: _mapController,
                pickup: pickupLat != null && pickupLng != null
                    ? LatLng(pickupLat!, pickupLng!)
                    : null,
                drop: dropLat != null && dropLng != null ? LatLng(dropLat!, dropLng!) : null,
                customerListenable: _customerGps,
                initialCenter: mapCenter,
                initialZoom: _mapCenter == null ? 12 : 15,
                showRoute: pickupLat != null && dropLat != null,
                routePoints: pickupLat != null &&
                        pickupLng != null &&
                        dropLat != null &&
                        dropLng != null
                    ? [
                        LatLng(pickupLat!, pickupLng!),
                        LatLng(dropLat!, dropLng!),
                      ]
                    : null,
                interactive: true,
                onMapReady: () {
                  if (mounted) setState(() => _mapReady = true);
                  if (_mapCenter != null) _moveMap(_mapCenter!, zoom: 15);
                },
              ),
            ),
            if (_mapCenter == null && _customerGps.value == null)
              const Center(
                child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
              ),
            Positioned(
              left: 8,
              top: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).size.height * 0.42,
              child: FloatingActionButton.small(
                heroTag: 'gps_center',
                backgroundColor: AppTheme.primary,
                onPressed: _isLocatingCurrent ? null : () => _useCurrentLocation(),
                child: _isLocatingCurrent
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.52,
                ),
                decoration: AppTheme.sheetDecoration(),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        const SizedBox(height: 14),
                        const Text(
                          'Book your ride',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Search or select pickup & drop below',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        _locationField(
                          label: 'Pickup',
                          hint: 'Search pickup location',
                          controller: _pickupController,
                          focusNode: _pickupFocus,
                          dotColor: AppTheme.success,
                          active: _isPickupActive,
                          onTap: () {
                            setState(() => _isPickupActive = true);
                            _pickupFocus.requestFocus();
                          },
                          onChanged: _isPickupActive ? _onSearchChanged : null,
                        ),
                        const SizedBox(height: 10),
                        _locationField(
                          label: 'Drop',
                          hint: 'Search drop location',
                          controller: _dropController,
                          focusNode: _dropFocus,
                          dotColor: AppTheme.danger,
                          active: !_isPickupActive,
                          onTap: () {
                            setState(() => _isPickupActive = false);
                            _dropFocus.requestFocus();
                          },
                          onChanged: !_isPickupActive ? _onSearchChanged : null,
                        ),
                        if (_isLoading || _suggestions.isNotEmpty || _error != null) ...[
                          const SizedBox(height: 10),
                          _buildSuggestionsList(),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLocatingCurrent ? null : () => _useCurrentLocation(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.primary),
                                  foregroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: _isLocatingCurrent
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location_rounded, size: 18),
                                label: Text(
                                  _currentLocationLabel,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _clearLocations,
                              icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                              tooltip: 'Reset',
                            ),
                          ],
                        ),
                        if (_error != null && !_isLocatingCurrent && _suggestions.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.onPrimary,
                              disabledBackgroundColor: AppTheme.surfaceLight,
                              disabledForegroundColor: AppTheme.textMuted,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _canConfirm ? _confirmBooking : null,
                            icon: const Icon(Icons.check_circle_outline_rounded),
                            label: const Text(
                              'Confirm & Select Vehicle',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _confirmBooking() async {
    // Lock the on-screen pickup pin. Nearby drivers match THIS location only —
    // never the phone's live GPS after the customer has set pickup/drop.
    _pickupTracksGps = false;
    _pickupManuallyEdited = true;

    final pLat = pickupLat!;
    final pLng = pickupLng!;
    final pAddr = pickupAddress ?? _pickupController.text.trim();
    if (!ChennaiArea.contains(pLat, pLng) ||
        !ChennaiArea.contains(dropLat!, dropLng!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChennaiArea.outOfAreaMessage)),
      );
      return;
    }
    final dAddr = dropAddress ?? _dropController.text.trim();
    await BookingDraftStore.save(
      pickupLat: pLat,
      pickupLng: pLng,
      pickupAddress: pAddr,
      dropLat: dropLat!,
      dropLng: dropLng!,
      dropAddress: dAddr,
    );
    if (!context.mounted) return;
    Navigator.pushNamed(
      context,
      '/taxi-selection',
      arguments: {
        'pickupLatLng': LatLng(pLat, pLng),
        'dropoffLatLng': LatLng(dropLat!, dropLng!),
        'pickupAddress': pAddr,
        'dropoffAddress': dAddr,
        'pickup': pAddr,
        'dropoff': dAddr,
        'fromHomeGps': false,
      },
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: const TextStyle(color: AppTheme.danger)),
                  ),
                )
              : _suggestions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No results found',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.5)),
                      itemBuilder: (context, index) {
                        final place = _suggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined, color: AppTheme.primary),
                          title: Text(
                            place.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () => _applySearchSelection(
                            lat: place.lat,
                            lng: place.lon,
                            address: place.displayName,
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _locationField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Color dotColor,
    required bool active,
    required VoidCallback onTap,
    required ValueChanged<String>? onChanged,
  }) {
    return Material(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? AppTheme.primary : AppTheme.border,
              width: active ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onTap: onTap,
                  cursorColor: AppTheme.primary,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    suffixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: active ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
