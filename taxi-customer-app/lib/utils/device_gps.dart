import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'chennai_area.dart';

/// Shared device GPS helpers for booking location screens.
class DeviceGps {
  static const _maxLastKnownAge = Duration(seconds: 30);

  static Future<String?> ensureReady() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return 'Turn on location services (GPS) in your device settings.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Location permission denied. Allow location access to use current position.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission blocked. Enable it in app settings.';
    }
    return null;
  }

  /// Device GPS without remapping — used when a chosen pin must not be replaced.
  static Future<LatLng> rawCurrentLatLng({bool highAccuracy = true}) async {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      final age = DateTime.now().difference(last.timestamp);
      if (age <= _maxLastKnownAge) {
        return LatLng(last.latitude, last.longitude);
      }
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy:
          highAccuracy ? LocationAccuracy.bestForNavigation : LocationAccuracy.best,
      timeLimit: const Duration(seconds: 15),
    ).timeout(const Duration(seconds: 18));

    return LatLng(position.latitude, position.longitude);
  }

  /// Fresh high-accuracy position; out-of-service-area GPS falls back to app center.
  static Future<LatLng> currentLatLng({bool highAccuracy = true}) async {
    return ChennaiArea.inServiceOrFallback(
      await rawCurrentLatLng(highAccuracy: highAccuracy),
    );
  }

  static Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    );
  }
}
