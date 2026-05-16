import 'package:flutter/services.dart';

class HapticEngine {
  static DateTime _lastFire = DateTime.fromMillisecondsSinceEpoch(0);

  // Volej každý frame s resistance 0–1
  static Future<void> tickResistance(double resistance) async {
    if (resistance < 0.15) return;

    final now = DateTime.now();
    // Throttle — ne víc než 30x/s
    if (now.difference(_lastFire).inMilliseconds < 33) return;
    _lastFire = now;

    if (resistance > 0.7) {
      await HapticFeedback.heavyImpact();
    } else if (resistance > 0.4) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  static Future<void> flick() => HapticFeedback.heavyImpact();
  static Future<void> connect() => HapticFeedback.mediumImpact();
  static Future<void> disconnect() => HapticFeedback.lightImpact();
}
