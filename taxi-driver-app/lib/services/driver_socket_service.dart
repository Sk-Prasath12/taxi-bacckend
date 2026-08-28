import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:taxiapp/api/api_constants.dart';
import 'package:taxiapp/utils/navigation_logger.dart';

class DriverSocketService {
  DriverSocketService._internal();
  static final DriverSocketService _instance = DriverSocketService._internal();
  factory DriverSocketService() => _instance;

  io.Socket? _socket;
  String? _driverId;
  String? _activeRideId;
  bool _connected = false;

  final StreamController<Map<String, dynamic>> _rideNewController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _rideUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _rideAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _paymentSuccessController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _paymentPendingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _paymentFailedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _rideCompletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _rideCancelledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _verificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get rideNewStream => _rideNewController.stream;
  Stream<Map<String, dynamic>> get rideUpdateStream => _rideUpdateController.stream;
  Stream<Map<String, dynamic>> get rideCancelledStream => _rideCancelledController.stream;
  Stream<Map<String, dynamic>> get rideAcceptedStream => _rideAcceptedController.stream;
  Stream<Map<String, dynamic>> get paymentSuccessStream => _paymentSuccessController.stream;
  Stream<Map<String, dynamic>> get paymentPendingStream => _paymentPendingController.stream;
  Stream<Map<String, dynamic>> get paymentFailedStream => _paymentFailedController.stream;
  Stream<Map<String, dynamic>> get rideCompletedStream => _rideCompletedController.stream;
  Stream<Map<String, dynamic>> get verificationStream => _verificationController.stream;

  bool get isConnected => _connected && (_socket?.connected ?? false);

  Future<void> connect({
    required String token,
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    _driverId = driverId;

    if (_connected && _socket != null) {
      updateLocation(lat: lat, lng: lng);
      return;
    }

    _socket = io.io(
      ApiConstants.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      if (kDebugMode) debugPrint('DriverSocket: connected');
      _socket!.emit('join', {'userId': driverId, 'role': 'driver'});
      _socket!.emit('driver:online', {
        'driverId': driverId,
        'location': {'lat': lat, 'lng': lng},
      });
      final rideId = _activeRideId;
      if (rideId != null && rideId.isNotEmpty) {
        _socket!.emit('join_ride_room', rideId);
      }
    });

    _socket!.onConnectError((dynamic err) {
      if (kDebugMode) debugPrint('DriverSocket: connect error $err');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      if (kDebugMode) debugPrint('DriverSocket: disconnected');
    });

    // REST confirm emits new_ride; socket booking emits ride:request
    _socket!.on('new_ride', (dynamic payload) {
      _rideNewController.add(_normalizeRidePayload(payload));
    });
    _socket!.on('ride:request', (dynamic payload) {
      _rideNewController.add(_normalizeRidePayload(payload));
    });
    _socket!.on('ride:new', (dynamic payload) {
      _rideNewController.add(_normalizeRidePayload(payload));
    });
    _socket!.on('ride_status_update', (dynamic payload) {
      _rideUpdateController.add(_normalize(payload));
    });
    _socket!.on('ride:status:update', (dynamic payload) {
      _rideUpdateController.add(_normalize(payload));
    });
    _socket!.on('ride:update', (dynamic payload) {
      _rideUpdateController.add(_normalize(payload));
    });
    _socket!.on('ride_unavailable', (dynamic payload) {
      final map = _normalize(payload);
      _rideUpdateController.add(map);
      _rideCancelledController.add(map);
    });
    _socket!.on('ride_cancelled', (dynamic payload) {
      final map = _normalize(payload);
      _rideUpdateController.add(map);
      _rideCancelledController.add(map);
    });
    _socket!.on('ride:cancelled', (dynamic payload) {
      final map = _normalize(payload);
      _rideUpdateController.add(map);
      _rideCancelledController.add(map);
    });
    _socket!.on('driver:verification', (dynamic payload) {
      _verificationController.add(_normalize(payload));
    });
    _socket!.on('admin_driver_approved', (dynamic payload) {
      _verificationController.add(_normalize(payload));
    });
    _socket!.on('admin_driver_rejected', (dynamic payload) {
      _verificationController.add(_normalize(payload));
    });
    _socket!.on('driver:verification:update', (dynamic payload) {
      _verificationController.add(_normalize(payload));
    });
    _socket!.on('ride:accepted', (dynamic payload) {
      _rideAcceptedController.add(_normalize(payload));
    });
    _socket!.on('ride:accept:ack', (dynamic payload) {
      _rideAcceptedController.add(_normalize(payload));
    });
    _socket!.on('payment_success', (dynamic payload) {
      _paymentSuccessController.add(_normalize(payload));
    });
    _socket!.on('payment_pending', (dynamic payload) {
      _paymentPendingController.add(_normalize(payload));
    });
    _socket!.on('payment_failed', (dynamic payload) {
      _paymentFailedController.add(_normalize(payload));
    });
    _socket!.on('ride_completed', (dynamic payload) {
      _rideCompletedController.add(_normalize(payload));
    });
    _socket!.on('invoice_updated', (dynamic payload) {
      _paymentSuccessController.add(_normalize(payload));
    });
    _socket!.on('wallet_updated', (dynamic payload) {
      _paymentSuccessController.add(_normalize(payload));
    });
    _socket!.on('driver_wallet_updated', (dynamic payload) {
      _paymentSuccessController.add(_normalize(payload));
    });
  }

  Map<String, dynamic> _normalizeRidePayload(dynamic payload) {
    final map = _normalize(payload);
    return {
      ...map,
      'rideId': map['rideId'] ?? map['ride_id'] ?? map['id'],
      'ride_id': map['ride_id'] ?? map['rideId'] ?? map['id'],
    };
  }

  void joinRideRoom(String rideId) {
    if (rideId.isEmpty) return;
    _activeRideId = rideId;
    _socket?.emit('join_ride_room', rideId);
    NavigationLogger.socket('join_ride_room', rideId: rideId, lat: null, lng: null);
  }

  void updateLocation({required double lat, required double lng}) {
    if (_driverId == null || _driverId!.isEmpty) return;
    _socket?.emit('location:update', {
      'driverId': _driverId,
      'location': {'lat': lat, 'lng': lng},
    });
    NavigationLogger.socket('location:update', rideId: null, lat: lat, lng: lng);
  }

  /// Sends GPS to customer tracking during an assigned ride.
  void updateLocationForRide({
    required String rideId,
    required double lat,
    required double lng,
    double? speedKmh,
    double? heading,
  }) {
    if (_driverId == null || rideId.isEmpty) return;
    final payload = <String, dynamic>{
      'ride_id': rideId,
      'driver_id': _driverId,
      'lat': lat,
      'lng': lng,
      'speed': ?speedKmh,
      'heading': ?heading,
      'bearing': ?heading,
    };
    NavigationLogger.socket('ride:location', rideId: rideId, lat: lat, lng: lng);
    _socket?.emit('driver_location', payload);
    _socket?.emit('driver_location_update', payload);
    _socket?.emit('ride:location', {
      'rideId': rideId,
      'location': {'lat': lat, 'lng': lng},
    });
    _socket?.emit('location:update', {
      'driverId': _driverId,
      'location': {'lat': lat, 'lng': lng},
    });
  }

  Future<Map<String, dynamic>> acceptRide(String rideId) => _emitAck('ride:accept', {'rideId': rideId});
  Future<Map<String, dynamic>> markArrived(String rideId) => _emitAck('ride:arrived', {'rideId': rideId});
  Future<Map<String, dynamic>> verifyOtp(String rideId, String otp) =>
      _emitAck('ride:verify_otp', {'rideId': rideId, 'otp': otp});
  Future<Map<String, dynamic>> startRide(String rideId) => _emitAck('ride:start', {'rideId': rideId});
  Future<Map<String, dynamic>> endRide(String rideId, {double? fare}) =>
      _emitAck('ride:end', {'rideId': rideId, 'fare': fare});

  Future<Map<String, dynamic>> _emitAck(String event, Map<String, dynamic> payload) async {
    final completer = Completer<Map<String, dynamic>>();
    _socket?.emitWithAck(event, payload, ack: (dynamic response) {
      if (!completer.isCompleted) {
        completer.complete(_normalize(response));
      }
    });
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => <String, dynamic>{'success': false, 'message': 'Socket timeout.'},
    );
  }

  Map<String, dynamic> _normalize(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }

  void dispose() {
    disconnect();
    _rideNewController.close();
    _rideUpdateController.close();
    _rideAcceptedController.close();
    _paymentSuccessController.close();
    _paymentPendingController.close();
    _paymentFailedController.close();
    _rideCompletedController.close();
    _rideCancelledController.close();
  }
}
