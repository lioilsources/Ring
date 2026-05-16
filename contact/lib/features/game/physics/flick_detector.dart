import 'dart:ui';
import 'ring_body.dart';
import 'constants.dart';

class FlickDetector {
  Offset? _prevPos;

  // Vrací impulse nebo null; voláno každý frame při aktivním doteku
  Offset? update(Offset currentPos, double dt) {
    final prev = _prevPos;
    _prevPos = currentPos;
    if (prev == null) return null;

    final fingerVel = (currentPos - prev) / dt;
    if (fingerVel.distance < kFlickThreshold) return null;

    return fingerVel * kFlickScale * kRingMass;
  }

  void reset() => _prevPos = null;
}
