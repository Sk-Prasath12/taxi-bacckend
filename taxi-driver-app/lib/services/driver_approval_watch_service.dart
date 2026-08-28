import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';

/// Polls driver profile while admin approval is pending (Vercel has no Socket.IO).
class DriverApprovalWatchService {
  DriverApprovalWatchService._();
  static final DriverApprovalWatchService instance = DriverApprovalWatchService._();

  static const Duration _pollInterval = Duration(seconds: 5);

  Timer? _timer;
  bool _running = false;
  bool _wasApproved = false;

  final StreamController<void> _approvedController = StreamController<void>.broadcast();

  Stream<void> get onApproved => _approvedController.stream;

  bool get isWatching => _running;

  void start() {
    final auth = AuthService();
    if (!auth.isLoggedIn || auth.canAcceptRides) {
      stop();
      return;
    }
    if (_running) return;
    _running = true;
    _wasApproved = auth.canAcceptRides;
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
    unawaited(_poll());
    if (kDebugMode) {
      debugPrint('DriverApprovalWatch: started (poll every ${_pollInterval.inSeconds}s)');
    }
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Immediate check — e.g. when app returns to foreground.
  Future<void> checkNow() async {
    final auth = AuthService();
    if (!auth.isLoggedIn || auth.canAcceptRides) return;
    await _poll(force: true);
  }

  Future<void> _poll({bool force = false}) async {
    if (!_running && !force) return;

    final auth = AuthService();
    if (!auth.isLoggedIn) {
      stop();
      return;
    }

    if (auth.canAcceptRides) {
      if (!_wasApproved) {
        _wasApproved = true;
        _approvedController.add(null);
      }
      stop();
      return;
    }

    final ok = await auth.refreshProfileFromApi();
    if (!ok) return;

    if (auth.canAcceptRides && !_wasApproved) {
      _wasApproved = true;
      _approvedController.add(null);
      stop();
    }
  }

  void resetForNewSession() {
    _wasApproved = false;
  }
}
