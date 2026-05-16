import 'dart:ui';
import 'ring_body.dart';
import 'flick_detector.dart';

class PhysicsWorld {
  late RingBody ring;

  Offset? localFingerPos;
  bool localFingerActive = false;

  Offset? remoteFingerPos;
  bool remoteFingerActive = false;

  final FlickDetector _flickDetector = FlickDetector();

  // Poslední lokální impulse pro broadcast
  Offset? pendingImpulse;

  // Poslední resistance (pro haptics)
  double lastResistance = 0.0;

  PhysicsWorld(Size bounds) {
    ring = RingBody(position: Offset(bounds.width / 2, bounds.height / 2));
  }

  void tick(double dt, Size bounds) {
    pendingImpulse = null;

    Offset localForce = Offset.zero;
    Offset remoteForce = Offset.zero;

    if (localFingerActive && localFingerPos != null) {
      localForce = ring.fingerForce(localFingerPos!);
      ring.applyForce(localForce, dt);

      final flick = _flickDetector.update(localFingerPos!, dt);
      if (flick != null) {
        ring.applyImpulse(flick);
        pendingImpulse = flick;
      }
    } else {
      _flickDetector.reset();
    }

    if (remoteFingerActive && remoteFingerPos != null) {
      remoteForce = ring.fingerForce(remoteFingerPos!);
      ring.applyForce(remoteForce, dt);
    }

    lastResistance = ring.calcResistance(localForce, remoteForce);

    ring.tick(dt, bounds);
  }

  void applyRemoteImpulse(Offset impulse) {
    ring.applyImpulse(impulse);
  }

  void applySyncHint(Offset pos, Offset vel) {
    ring.applySyncHint(pos, vel);
  }
}
