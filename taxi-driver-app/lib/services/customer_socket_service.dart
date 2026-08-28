import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:taxiapp/api/api_constants.dart';

class CustomerSocketService {
  CustomerSocketService._internal();
  static final CustomerSocketService _instance = CustomerSocketService._internal();
  factory CustomerSocketService() => _instance;

  io.Socket? _socket;
  bool _connected = false;

  final StreamController<Map<String, dynamic>> _acceptedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _statusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _paymentController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _paymentSuccessController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _rideCompletedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get rideAcceptedStream => _acceptedController.stream;
  Stream<Map<String, dynamic>> get statusUpdateStream => _statusController.stream;
  Stream<Map<String, dynamic>> get paymentPendingStream => _paymentController.stream;
  Stream<Map<String, dynamic>> get paymentSuccessStream => _paymentSuccessController.stream;
  Stream<Map<String, dynamic>> get rideCompletedStream => _rideCompletedController.stream;

  Future<void> connect({required String token, required String customerId, String? rideId}) async {
    if (_connected && _socket != null) {
      if (rideId != null) _socket!.emit('join_ride_room', rideId);
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
      _socket!.emit('join', {
        'userId': customerId,
        'role': 'customer',
        'rideId': ?rideId,
      });
      if (rideId != null) _socket!.emit('join_ride_room', rideId);
    });

    _socket!.onDisconnect((_) => _connected = false);

    for (final event in ['ride_accepted', 'ride:accepted']) {
      _socket!.on(event, (p) => _acceptedController.add(_map(p)));
    }
    for (final event in ['ride_status_update', 'ride:status:update']) {
      _socket!.on(event, (p) => _statusController.add(_map(p)));
    }
    _socket!.on('payment_pending', (p) {
      final map = _map(p);
      _paymentController.add(map);
      _statusController.add(map);
    });
    for (final event in [
      'otp_generated',
      'pickup_otp_generated',
      'pickup_otp_verified',
      'otp_verified',
      'driver_arrived',
      'drop_reached',
      'drop_otp_verified',
      'drop_otp_generated',
    ]) {
      _socket!.on(event, (p) => _statusController.add(_map(p)));
    }
    for (final event in ['driver_location', 'driver_location_update', 'driver:location:update']) {
      _socket!.on(event, (p) => _statusController.add({..._map(p), 'event': 'driver_location'}));
    }
    for (final event in ['payment_success', 'wallet_updated']) {
      _socket!.on(event, (p) {
        final map = _map(p);
        _paymentSuccessController.add(map);
        _statusController.add(map);
      });
    }
    for (final event in ['ride_completed', 'ride:completed']) {
      _socket!.on(event, (p) {
        final map = _map(p);
        _rideCompletedController.add(map);
        _statusController.add(map);
      });
    }
    _socket!.on('ride:update', (p) => _statusController.add(_map(p)));
    for (final event in ['ride:cancelled', 'ride_cancelled']) {
      _socket!.on(event, (p) {
        final map = _map(p);
        _statusController.add({...map, 'status': 'cancelled'});
      });
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }

  Map<String, dynamic> _map(dynamic p) {
    if (p is Map<String, dynamic>) return p;
    if (p is Map) return p.map((k, v) => MapEntry(k.toString(), v));
    return {};
  }
}
