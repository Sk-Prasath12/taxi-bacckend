import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import 'active_ride_store.dart';
import 'customer_session_store.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  String? _token;
  bool _joined = false;
  bool _reconnectScheduled = false;
  final List<void Function()> _readyListeners = [];

  static String get _socketBase => ApiConfig.socketUrl;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> init() async {
    await connect();
  }

  /// Screens re-bind listeners when the underlying socket is recreated.
  void onReady(void Function() listener) {
    if (!_readyListeners.contains(listener)) {
      _readyListeners.add(listener);
    }
  }

  void offReady(void Function() listener) {
    _readyListeners.remove(listener);
  }

  void _notifyReady() {
    for (final listener in List<void Function()>.from(_readyListeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  Future<String?> _resolveToken() async {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString('token') ??
        prefs.getString('access_token') ??
        prefs.getString('auth_token');
    if (fromPrefs != null && fromPrefs.isNotEmpty) return fromPrefs;
    return CustomerSessionStore.getAccessToken();
  }

  Future<void> connect() async {
    print('BASE URL: $_socketBase');
    final token = await _resolveToken();
    if (token == null || token.isEmpty) return;

    // Reuse existing socket when token matches (keeps listeners alive).
    if (_socket != null && _token == token) {
      if (_socket!.connected) {
        _emitJoinIfPossible();
        return;
      }
      _socket!.connect();
      return;
    }

    _token = token;
    _joined = false;
    _socket?.dispose();
    _socket = io.io(
      _socketBase,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setAuth({'token': token})
          .enableForceNew()
          .build(),
    );
    _socket?.onConnect((_) {
      print('SOCKET CONNECTED');
      _joined = false;
      _reconnectScheduled = false;
      _emitJoinIfPossible();
      unawaited(_rejoinActiveRideRoom());
      _notifyReady();
    });
    _socket?.onDisconnect((_) {
      print('SOCKET DISCONNECTED');
      _joined = false;
      // Library already reconnects; only nudge once if still down.
      if (_reconnectScheduled) return;
      _reconnectScheduled = true;
      Future.delayed(const Duration(seconds: 5), () {
        _reconnectScheduled = false;
        if (_socket?.connected != true) {
          unawaited(connect());
        }
      });
    });
    _socket?.onConnectError((err) {
      print('CONNECT ERROR: $err');
    });
    _socket?.onAny((event, data) {
      print('EVENT: $event DATA: $data');
    });
    _socket?.connect();
  }

  String? _extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final jsonMap = jsonDecode(payload);
      if (jsonMap is Map<String, dynamic>) {
        final sub = jsonMap['sub']?.toString();
        if (sub != null && sub.isNotEmpty) return sub;
        final customerId = jsonMap['customerId']?.toString();
        if (customerId != null && customerId.isNotEmpty) return customerId;
      }
    } catch (_) {}
    return null;
  }

  void _emitJoinIfPossible() {
    final socket = _socket;
    final token = _token;
    if (socket == null || token == null || !socket.connected || _joined) return;
    final userId = _extractUserIdFromToken(token);
    if (userId == null) return;
    socket.emit('join', {'userId': userId, 'role': 'customer'});
    _joined = true;
    print('Customer joined socket: customer_$userId');
  }

  void joinCustomerRoom() {
    _emitJoinIfPossible();
  }

  void joinCustomerRide(String rideId) {
    final socket = _socket;
    final token = _token;
    if (socket == null || token == null || !socket.connected || rideId.isEmpty) {
      return;
    }
    final userId = _extractUserIdFromToken(token);
    if (userId == null) return;
    socket
        .emit('join', {'userId': userId, 'role': 'customer', 'rideId': rideId});
  }

  void joinRideRoom(String rideId) {
    if (rideId.isEmpty) return;
    _socket?.emit('join_ride_room', rideId);
    print('Joined ride room: $rideId');
  }

  Future<void> _rejoinActiveRideRoom() async {
    final cached = await ActiveRideStore.load();
    final rideId =
        cached?['ride_id']?.toString() ?? cached?['id']?.toString() ?? '';
    if (rideId.isEmpty) return;
    joinCustomerRide(rideId);
    joinRideRoom(rideId);
  }

  void emitCustomerLocation({
    required double lat,
    required double lng,
    String? rideId,
  }) {
    if (_socket?.connected != true) return;
    _socket?.emit('customer:location', {
      'lat': lat,
      'lng': lng,
      if (rideId != null && rideId.isNotEmpty) 'rideId': rideId,
    });
  }

  void onRideAccepted(void Function(dynamic) handler) =>
      _socket?.on('ride_accepted', handler);

  /// Backend emits `driver_location` and `driver_location_update` (same payload shape).
  void onDriverLocation(void Function(dynamic) handler) {
    _socket?.on('driver_location', handler);
    _socket?.on('driver_location_update', handler);
    _socket?.on('location_updated', handler);
  }

  static const _lifecycleEvents = [
    'payment_success',
    'payment_pending',
    'otp_generated',
    'drop_otp_generated',
    'pickup_otp_generated',
    'ride_completed',
    'drop_reached',
    'drop_otp_verified',
    'trip_started',
    'pickup_otp_verified',
    'driver_arrived',
    'gps_tracking_started',
  ];

  void onPaymentSuccess(void Function(dynamic) handler) {
    for (final event in _lifecycleEvents) {
      _socket?.on(event, handler);
    }
  }

  void offPaymentSuccess([void Function(dynamic)? handler]) {
    final s = _socket;
    if (s == null) return;
    for (final event in _lifecycleEvents) {
      if (handler != null) {
        s.off(event, handler);
      } else {
        s.off(event);
      }
    }
  }

  void onRideStatusUpdate(void Function(dynamic) handler) =>
      _socket?.on('ride_status_update', handler);
  void onInvoiceGenerated(void Function(dynamic) handler) =>
      _socket?.on('invoice_generated', handler);
  void onRideTrackingUpdate(void Function(dynamic) handler) =>
      _socket?.on('ride-tracking-update', handler);

  /// Pass the same [handler] reference used in `on*` so other screens' listeners stay registered.
  void offRideAccepted([void Function(dynamic)? handler]) {
    final s = _socket;
    if (s == null) return;
    if (handler != null) {
      s.off('ride_accepted', handler);
    } else {
      s.off('ride_accepted');
    }
  }

  void offDriverLocation([void Function(dynamic)? handler]) {
    final s = _socket;
    if (s == null) return;
    if (handler != null) {
      s.off('driver_location', handler);
      s.off('driver_location_update', handler);
      s.off('location_updated', handler);
    } else {
      s.off('driver_location');
      s.off('driver_location_update');
      s.off('location_updated');
    }
  }

  void offRideStatusUpdate([void Function(dynamic)? handler]) {
    final s = _socket;
    if (s == null) return;
    if (handler != null) {
      s.off('ride_status_update', handler);
    } else {
      s.off('ride_status_update');
    }
  }

  void offInvoiceGenerated([void Function(dynamic)? handler]) {
    final s = _socket;
    if (s == null) return;
    if (handler != null) {
      s.off('invoice_generated', handler);
    } else {
      s.off('invoice_generated');
    }
  }

  void offRideTrackingUpdate([void Function(dynamic)? handler]) {
    final s = _socket;
    if (s == null) return;
    if (handler != null) {
      s.off('ride-tracking-update', handler);
    } else {
      s.off('ride-tracking-update');
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _joined = false;
    _reconnectScheduled = false;
  }
}
