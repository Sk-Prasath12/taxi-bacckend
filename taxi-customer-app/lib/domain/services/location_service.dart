import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

import '../../utils/chennai_area.dart';

enum LocationState { initial, loading, success, error, permissionDenied }

class LocationData {
  final LatLng? position;
  final LocationState state;
  final String? errorMessage;

  LocationData({this.position, required this.state, this.errorMessage});
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _statusController = StreamController<LocationData>.broadcast();
  Stream<LocationData> get statusStream => _statusController.stream;

  Future<LocationData> getCurrentLocation() async {
    _statusController.add(LocationData(state: LocationState.loading));

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _error(LocationState.error, 'Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _error(LocationState.permissionDenied, 'Permission denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _error(
          LocationState.permissionDenied,
          'Permission permanently denied.',
        );
      }

      // Try last known first
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        final data = LocationData(
          position: ChennaiArea.inServiceOrFallback(
            LatLng(lastPos.latitude, lastPos.longitude),
          ),
          state: LocationState.success,
        );
        _statusController.add(data);
      }

      // Force fresh position with strict timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 18));

      final data = LocationData(
        position: ChennaiArea.inServiceOrFallback(
          LatLng(position.latitude, position.longitude),
        ),
        state: LocationState.success,
      );
      _statusController.add(data);
      return data;
    } catch (e) {
      return _error(LocationState.error, e.toString());
    }
  }

  LocationData _error(LocationState state, String msg) {
    final data = LocationData(state: state, errorMessage: msg);
    _statusController.add(data);
    return data;
  }

  StreamSubscription<Position>? _positionSubscription;

  void startTracking() {
    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen(
          (Position position) {
            _statusController.add(
              LocationData(
                position: ChennaiArea.inServiceOrFallback(
                  LatLng(position.latitude, position.longitude),
                ),
                state: LocationState.success,
              ),
            );
          },
          onError: (e) {
            _error(LocationState.error, e.toString());
          },
        );
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
