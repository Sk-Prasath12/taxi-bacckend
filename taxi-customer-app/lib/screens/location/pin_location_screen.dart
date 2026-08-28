import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/booking_draft_store.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/chennai_area.dart';
import '../../utils/device_gps.dart';
import '../../widgets/app_map_view.dart';

enum LocationPickMode { pickup, drop }

/// Dedicated pickup or drop screen: search + center pin on map.
class PinLocationScreen extends StatefulWidget {
  final LocationPickMode mode;

  const PinLocationScreen({super.key, required this.mode});

  const PinLocationScreen.pickup({super.key}) : mode = LocationPickMode.pickup;

  const PinLocationScreen.drop({super.key}) : mode = LocationPickMode.drop;

  @override
  State<PinLocationScreen> createState() => _PinLocationScreenState();
}

class _PinLocationScreenState extends State<PinLocationScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _nominatim = NominatimLocationService();
  final _mapController = MapController();

  List<PlaceSuggestion> _suggestions = [];
  Timer? _searchDebounce;
  Timer? _geocodeDebounce;
  bool _searching = false;
  bool _confirming = false;
  bool _mapReady = false;
  bool _moving = false;
  String? _error;
  String _address = '';
  LatLng _pin = const LatLng(13.0827, 80.2707);

  bool get _isPickup => widget.mode == LocationPickMode.pickup;
  String get _title => _isPickup ? 'Pickup location' : 'Drop location';
  String get _hint => _isPickup
      ? 'Search pickup address or landmark'
      : 'Search drop address or landmark';
  String get _confirmLabel =>
      _isPickup ? 'Confirm pickup' : 'Confirm drop';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    LatLng? initial;
    String? initialAddress;

    if (args is Map) {
      final ll = args['initialLatLng'] ??
          args['initialPickupLatLng'] ??
          (!_isPickup ? args['pickupLatLng'] : null);
      if (ll is LatLng) initial = ll;
      initialAddress = args['initialAddress']?.toString();
      if (!_isPickup &&
          (initialAddress == null || initialAddress.isEmpty) &&
          args['pickupAddress'] is String) {
        // Start near pickup; address will reverse-geocode for drop pin.
      }
    }

    if (initial == null) {
      final draft = await BookingDraftStore.load();
      if (draft != null) {
        if (_isPickup) {
          final lat = (draft['pickupLat'] as num?)?.toDouble();
          final lng = (draft['pickupLng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            initial = LatLng(lat, lng);
            initialAddress = draft['pickupAddress']?.toString();
          }
        } else {
          final lat = (draft['dropLat'] as num?)?.toDouble();
          final lng = (draft['dropLng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            initial = LatLng(lat, lng);
            initialAddress = draft['dropAddress']?.toString();
          } else {
            final pLat = (draft['pickupLat'] as num?)?.toDouble();
            final pLng = (draft['pickupLng'] as num?)?.toDouble();
            if (pLat != null && pLng != null) {
              initial = LatLng(pLat, pLng);
            }
          }
        }
      }
    }

    if (initial == null) {
      try {
        final blocked = await DeviceGps.ensureReady();
        if (blocked == null) {
          initial = await DeviceGps.currentLatLng();
        }
      } catch (_) {}
    }

    initial = ChennaiArea.inServiceOrFallback(initial ?? _pin);
    _pin = initial;
    if (initialAddress != null && initialAddress.trim().isNotEmpty) {
      _address = initialAddress.trim();
      _searchController.text = _address;
    } else {
      await _reverseGeocode(_pin);
    }
    if (!mounted) return;
    setState(() {});
    _moveMap(_pin);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _searchDebounce?.cancel();
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  void _moveMap(LatLng target, {double zoom = 16}) {
    if (!_mapReady) return;
    try {
      _mapController.move(target, zoom);
    } catch (_) {}
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final addr = await _nominatim.reverseGeocode(point.latitude, point.longitude);
      if (!mounted) return;
      setState(() {
        _address = (addr != null && addr.trim().isNotEmpty)
            ? addr.trim()
            : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        if (!_searchFocus.hasFocus) {
          _searchController.text = _address;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      });
    }
  }

  void _onMapMoved(LatLng center, double zoom) {
    final next = ChennaiArea.inServiceOrFallback(center);
    setState(() {
      _pin = next;
      _moving = true;
      _suggestions = [];
      _error = null;
    });
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 450), () async {
      await _reverseGeocode(next);
      if (mounted) setState(() => _moving = false);
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _nominatim.searchPlaces(value);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _searching = false;
          _error = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _suggestions = [];
          _searching = false;
          _error = 'Search failed. Try again or pin on the map.';
        });
      }
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion place) async {
    final point = ChennaiArea.inServiceOrFallback(LatLng(place.lat, place.lon));
    setState(() {
      _pin = point;
      _address = place.displayName;
      _searchController.text = place.displayName;
      _suggestions = [];
      _searchFocus.unfocus();
    });
    _moveMap(point);
  }

  Future<void> _useCurrentLocation() async {
    try {
      final blocked = await DeviceGps.ensureReady();
      if (blocked != null) throw Exception(blocked);
      final latLng = await DeviceGps.currentLatLng();
      final point = ChennaiArea.inServiceOrFallback(latLng);
      setState(() {
        _pin = point;
        _suggestions = [];
        _error = null;
      });
      _moveMap(point);
      await _reverseGeocode(point);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    if (!ChennaiArea.containsLatLng(_pin)) {
      setState(() => _error = ChennaiArea.outOfAreaMessage);
      return;
    }
    final address = _address.trim().isNotEmpty
        ? _address.trim()
        : '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}';

    setState(() => _confirming = true);
    try {
      if (_isPickup) {
        await BookingDraftStore.savePickup(
          lat: _pin.latitude,
          lng: _pin.longitude,
          address: address,
        );
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          '/drop-location',
          arguments: {
            'pickupLatLng': _pin,
            'pickupAddress': address,
          },
        );
      } else {
        final draft = await BookingDraftStore.load();
        final pLat = (draft?['pickupLat'] as num?)?.toDouble();
        final pLng = (draft?['pickupLng'] as num?)?.toDouble();
        final pickupAddress = draft?['pickupAddress']?.toString() ?? '';
        if (pLat == null || pLng == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pickup is missing. Select pickup first.')),
          );
          Navigator.pushReplacementNamed(context, '/pickup-location');
          return;
        }
        await BookingDraftStore.saveDrop(
          lat: _pin.latitude,
          lng: _pin.longitude,
          address: address,
        );
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          '/taxi-selection',
          arguments: {
            'pickupLatLng': LatLng(pLat, pLng),
            'dropoffLatLng': _pin,
            'pickupAddress': pickupAddress,
            'dropoffAddress': address,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppMapView(
            mapController: _mapController,
            initialCenter: _pin,
            initialZoom: 16,
            interactive: true,
            showRoute: false,
            onMapReady: () {
              _mapReady = true;
              _moveMap(_pin);
            },
            onPositionChanged: _onMapMoved,
          ),
          // Fixed center pin — map moves under it.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: _isPickup ? AppTheme.success : AppTheme.danger,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  color: AppTheme.surface,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: _hint,
                              hintStyle: const TextStyle(color: AppTheme.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searching)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                            ),
                          )
                        else if (_searchController.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _suggestions = []);
                            },
                            icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                      itemBuilder: (context, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, color: AppTheme.primary, size: 20),
                          title: Text(
                            s.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          ),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 210,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'pin_my_location',
                  backgroundColor: AppTheme.surface,
                  onPressed: _useCurrentLocation,
                  child: const Icon(Icons.my_location_rounded, color: AppTheme.primary),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _moving ? 'Moving pin…' : (_address.isEmpty ? 'Drag the map to place the pin' : _address),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.3),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _confirming || _moving ? null : _confirm,
                        child: Text(_confirming ? 'Please wait…' : _confirmLabel),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Search above or drag the map to adjust the pin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textMuted.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
