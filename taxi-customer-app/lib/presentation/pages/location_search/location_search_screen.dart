import 'package:flutter/material.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../domain/services/osrm_service.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  bool choosingDropoff = false;
  String? pickupLocation;
  String? dropoffLocation;
  LatLng? pickupLatLng;
  LatLng? dropoffLatLng;
  final OsrmService _osrmService = OsrmService();
  final TextEditingController _searchController = TextEditingController();
  List<LocationSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;

  /// Live current location for "Use current location" box (map-style detailed address).
  String? _currentLocationAddress;
  LatLng? _currentLocationLatLng;
  bool _currentLocationError = false;
  bool _currentUsedForPickup = false;

  /// Car type chosen on taxi-selection (e.g. Small, Medium, Large). Passed to bill.
  String? _taxiType;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = true);
      final results = await _osrmService.searchLocation(query);
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLiveCurrentLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null && args['type'] != null && mounted) {
        setState(() => _taxiType = args['type']?.toString());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Fetches live current position and reverse-geocodes to detailed map address.
  Future<void> _loadLiveCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentLocationLatLng = LatLng(position.latitude, position.longitude);
        _currentLocationError = false;
      });
      final address = await _osrmService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _currentLocationAddress = address?.trim().isNotEmpty == true
            ? address
            : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentLocationError = true;
          _currentLocationAddress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          choosingDropoff ? 'Choose drop-off' : 'Choose pick-up',
          style: const TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: Icon(
            choosingDropoff ? Icons.arrow_back : Icons.close,
            color: Colors.black,
          ),
          onPressed: () {
            if (choosingDropoff) {
              setState(() => choosingDropoff = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: choosingDropoff
                    ? 'Enter destination...'
                    : 'Enter pick-up location...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFDB813)),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                fillColor: Colors.grey[100],
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              children: [
                if (_searchController.text.isEmpty &&
                    !(choosingDropoff && _currentUsedForPickup))
                  _buildCurrentLocationOption(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10,
                  ),
                  child: Text(
                    _searchController.text.isEmpty
                        ? (choosingDropoff
                              ? 'Suggested Destinations'
                              : 'Recent Searches')
                        : 'Search Results',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                if (!choosingDropoff && _searchController.text.isEmpty) ...[
                  _buildQuickLocationItem(
                    'Home',
                    '221B Baker Street',
                    Icons.home,
                    Colors.blue,
                    lat: 51.5237,
                    lon: -0.1585,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Divider(),
                  ),
                ],
                if (_searchController.text.isEmpty) ...[
                  _buildLocationResult(
                    context,
                    'Central Park',
                    'New York, NY, USA',
                    Icons.history,
                  ),
                  _buildLocationResult(
                    context,
                    'Times Square',
                    'Manhattan, NY 10036, USA',
                    Icons.history,
                  ),
                  _buildLocationResult(
                    context,
                    'Empire State Building',
                    '350 5th Ave, New York, NY 10118, USA',
                    Icons.location_on,
                  ),
                ] else
                  ..._suggestions.map(
                    (s) => _buildLocationResult(
                      context,
                      s.title,
                      s.subtitle,
                      Icons.location_on,
                      lat: s.lat,
                      lon: s.lon,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationOption() {
    String subtitle;
    if (_currentLocationError) {
      subtitle = 'Unable to get location. Tap to retry.';
    } else if (_currentLocationAddress != null) {
      subtitle = _currentLocationAddress!;
    } else {
      subtitle = 'Detecting your location…';
    }

    return ListTile(
      onTap: () async {
        // Helper to use the (lat, lng, address) either as pickup or dropoff.
        Future<void> _applyLocation(LatLng latLng, String address) async {
          final prettyAddress = address.trim().isNotEmpty
              ? address
              : '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';

          if (!choosingDropoff) {
            // Use current location as PICKUP, then move to dropoff step.
            setState(() {
              pickupLocation = prettyAddress;
              pickupLatLng = latLng;
              _currentLocationAddress = prettyAddress;
              _currentLocationLatLng = latLng;
              _currentLocationError = false;
              _currentUsedForPickup = true;
              choosingDropoff = true;
              _searchController.clear();
              _suggestions = [];
              _isLoading = false;
            });
          } else {
            // Use current location as DROPOFF and go to payment-selection.
            setState(() {
              dropoffLocation = prettyAddress;
              dropoffLatLng = latLng;
              _currentLocationAddress = prettyAddress;
              _currentLocationLatLng = latLng;
              _currentLocationError = false;
              _isLoading = false;
            });
            if (!mounted) return;
            Navigator.pushNamed(
              context,
              '/taxi-selection',
              arguments: {
                'pickup': pickupLocation,
                'dropoff': dropoffLocation,
                'pickupLatLng': pickupLatLng,
                'dropoffLatLng': dropoffLatLng,
                'pickupAddress': pickupLocation,
                'dropoffAddress': dropoffLocation,
              },
            );
          }
        }

        // If we already have a cached current location, reuse it.
        if (_currentLocationLatLng != null && _currentLocationAddress != null) {
          await _applyLocation(_currentLocationLatLng!, _currentLocationAddress!);
          return;
        }

        setState(() => _isLoading = true);
        try {
          final position = await Geolocator.getCurrentPosition();
          final latLng = LatLng(position.latitude, position.longitude);
          final address = await _osrmService.reverseGeocode(
            position.latitude,
            position.longitude,
          );
          if (!mounted) return;
          await _applyLocation(latLng, address ?? '');
        } catch (_) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not get current location')),
            );
          }
        }
      },
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFDB813),
        child: Icon(Icons.my_location, color: Colors.black, size: 18),
      ),
      title: const Text(
        'Use Current Location',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFDB813)),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Full address for map/bill: title + subtitle (detailed as per Nominatim).
  static String _fullAddress(String title, String subtitle) {
    final sub = subtitle.trim();
    return sub.isEmpty ? title : '$title, $sub'.trim();
  }

  Widget _buildLocationResult(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon, {
    double? lat,
    double? lon,
  }) {
    final detailedAddress = _fullAddress(title, subtitle);
    return ListTile(
      onTap: () {
        if (!choosingDropoff) {
          setState(() {
            pickupLocation = detailedAddress;
            pickupLatLng = lat != null && lon != null ? LatLng(lat, lon) : null;
            choosingDropoff = true;
            _searchController.clear();
            _suggestions = [];
          });
        } else {
          dropoffLocation = detailedAddress;
          dropoffLatLng = lat != null && lon != null ? LatLng(lat, lon) : null;
          // After selecting both locations, go to next screen
          Navigator.pushNamed(
            context,
            '/taxi-selection',
            arguments: {
              'pickup': pickupLocation,
              'dropoff': dropoffLocation,
              'pickupAddress': pickupLocation,
              'dropoffAddress': dropoffLocation,
              'pickupLatLng': pickupLatLng,
              'dropoffLatLng': dropoffLatLng,
            },
          );
        }
      },
      leading: CircleAvatar(
        backgroundColor: Colors.grey[100],
        child: Icon(icon, color: Colors.grey, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  Widget _buildQuickLocationItem(
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    double? lat,
    double? lon,
  }) {
    final detailedAddress = _fullAddress(title, subtitle);
    return ListTile(
      onTap: () {
        setState(() {
          pickupLocation = detailedAddress;
          pickupLatLng = lat != null && lon != null ? LatLng(lat, lon) : null;
          choosingDropoff = true;
          _searchController.clear();
          _suggestions = [];
        });
      },
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(30),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
    );
  }
}
