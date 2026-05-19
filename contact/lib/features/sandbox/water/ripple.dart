import 'dart:ui';
import '../../game/physics/constants.dart';

class WaterRipple {
  final Offset center;
  final double startTime; // animTime (s) when spawned
  final double strength;
  const WaterRipple(this.center, this.startTime, [this.strength = 1.0]);
}

class RippleField {
  final List<WaterRipple> _ripples = [];
  double _lastSpawn = -1.0;

  List<WaterRipple> get ripples => _ripples;

  void spawn(Offset p, double now) {
    if (now - _lastSpawn < kRippleMinSpawnGap) return;
    _lastSpawn = now;
    _ripples.add(WaterRipple(p, now));
    if (_ripples.length > kMaxRipples) _ripples.removeAt(0);
  }

  void prune(double now) {
    _ripples.removeWhere((r) => now - r.startTime > kRippleMaxAge);
  }
}
