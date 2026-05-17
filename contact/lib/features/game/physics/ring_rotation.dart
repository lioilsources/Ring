import 'dart:ui';

class RingRotation {
  double angleY = 0.0;
  double angleX = 0.3; // default ~17° tilt so ring always looks 3D

  double _spinY = 0.0; // rad/s around Y (coin-spin)
  double _spinX = 0.0; // rad/s around X (forward/back tilt)

  static const double _drag = 0.015;
  static const double _impulseScaleY = 0.08;
  static const double _impulseScaleX = 0.04;
  static const double _velocityScale = 0.0003;
  static const double _defaultTilt = 0.3;

  void applyImpulse(Offset impulse) {
    _spinY += impulse.dx * _impulseScaleY;
    _spinX -= impulse.dy * _impulseScaleX;
  }

  void applyVelocity(Offset vel) {
    _spinY += vel.dx * _velocityScale;
  }

  void tick(double dt) {
    _spinY *= (1.0 - _drag);
    _spinX *= (1.0 - _drag * 1.2);
    angleY += _spinY * dt;
    angleX += _spinX * dt;
    // Slowly return tilt to default so ring doesn't fall flat
    angleX += (_defaultTilt - angleX) * 0.001;
  }
}
