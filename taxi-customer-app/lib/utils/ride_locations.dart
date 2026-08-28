import 'package:latlong2/latlong.dart';

/// Parses `{ lat, lng }` / `{ latitude, longitude }` style maps from APIs and sockets.
LatLng? latLngFromMap(dynamic value) {
  if (value is LatLng) return value;
  if (value is! Map) return null;
  final map = Map<String, dynamic>.from(value);
  final lat = map['lat'] ?? map['latitude'];
  final lng = map['lng'] ?? map['longitude'] ?? map['lon'];
  if (lat is num && lng is num) {
    return LatLng(lat.toDouble(), lng.toDouble());
  }
  return null;
}

Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

LatLng? _pickupFromStatusLikeMap(Map<String, dynamic> root) {
  final direct = latLngFromMap(root['pickup']);
  if (direct != null) return direct;
  final ride = _asStringKeyedMap(root['ride']);
  if (ride != null) {
    final fromRide = latLngFromMap(ride['pickup']);
    if (fromRide != null) return fromRide;
  }
  return null;
}

LatLng? _dropFromStatusLikeMap(Map<String, dynamic> root) {
  final direct = latLngFromMap(root['drop']);
  if (direct != null) return direct;
  final ride = _asStringKeyedMap(root['ride']);
  if (ride != null) {
    final fromRide = latLngFromMap(ride['drop']);
    if (fromRide != null) return fromRide;
  }
  return null;
}

/// Pickup [LatLng] from booking / tracking route [arguments]: explicit [LatLng], embedded maps, or status/socket payloads.
LatLng? resolvePickupLatLng(Map<dynamic, dynamic>? args) {
  if (args == null) return null;
  final pickupArg = args['pickupLatLng'];
  final fromArg = latLngFromMap(pickupArg);
  if (fromArg != null) return fromArg;

  for (final key in ['statusPayload', 'initialData', 'acceptedPayload']) {
    final nested = _asStringKeyedMap(args[key]);
    if (nested == null) continue;
    final p = _pickupFromStatusLikeMap(nested);
    if (p != null) return p;
  }
  return null;
}

/// Dropoff [LatLng] from route [arguments] (same sources as [resolvePickupLatLng]).
LatLng? resolveDropLatLng(Map<dynamic, dynamic>? args) {
  if (args == null) return null;
  final dropArg = args['dropoffLatLng'];
  final fromArg = latLngFromMap(dropArg);
  if (fromArg != null) return fromArg;

  for (final key in ['statusPayload', 'initialData', 'acceptedPayload']) {
    final nested = _asStringKeyedMap(args[key]);
    if (nested == null) continue;
    final d = _dropFromStatusLikeMap(nested);
    if (d != null) return d;
  }
  return null;
}

/// Merges [baseArgs], optional [extraArgs], and [statusPayload], then injects
/// resolved [pickupLatLng] / [dropoffLatLng] so tracking and OSRM always see [LatLng] when the API sent coordinates.
Map<String, dynamic> buildRideTrackingArguments(
  Map<dynamic, dynamic>? baseArgs,
  Map<String, dynamic> statusPayload, {
  Map<String, dynamic>? extraArgs,
}) {
  final merged = <String, dynamic>{
    for (final e in (baseArgs ?? {}).entries) e.key.toString(): e.value,
    ...?extraArgs,
    'statusPayload': statusPayload,
  };
  final pickup = resolvePickupLatLng(merged);
  final drop = resolveDropLatLng(merged);
  if (pickup != null) merged['pickupLatLng'] = pickup;
  if (drop != null) merged['dropoffLatLng'] = drop;
  return merged;
}

/// Resolved pickup, drop, and live driver position for OSRM and the map.
class RideGeoPoints {
  final LatLng? pickup;
  final LatLng? drop;
  final LatLng? driver;

  const RideGeoPoints({this.pickup, this.drop, this.driver});

  factory RideGeoPoints.fromTrackingArgs(
    Map<dynamic, dynamic>? args, {
    LatLng? driverPosition,
  }) {
    return RideGeoPoints(
      pickup: resolvePickupLatLng(args),
      drop: resolveDropLatLng(args),
      driver: driverPosition,
    );
  }

  bool get hasPickupAndDrop => pickup != null && drop != null;

  bool get hasDriverPosition => driver != null;
}
