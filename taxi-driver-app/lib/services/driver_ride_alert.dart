import 'dart:async';

import 'package:flutter/services.dart';

/// Haptic + system alert while an incoming ride is waiting for accept/decline.
class DriverRideAlert {
  static Timer? _pulseTimer;

  static void play() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    _pulseTimer?.cancel();
    var count = 0;
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (count++ >= 22) {
        t.cancel();
        return;
      }
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  static void stop() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
  }
}
