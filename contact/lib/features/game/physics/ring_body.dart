import 'dart:ui';
import 'constants.dart';

extension OffsetX on Offset {
  Offset get normalized {
    final d = distance;
    if (d < 0.0001) return Offset.zero;
    return this / d;
  }

  double dot(Offset other) => dx * other.dx + dy * other.dy;

  Offset operator /(double divisor) => Offset(dx / divisor, dy / divisor);
}

class RingBody {
  Offset position;
  Offset velocity;

  final double mass;
  final double radius;
  final double drag;
  final double elasticity;
  final double wallFriction;

  RingBody({
    required this.position,
    this.velocity = Offset.zero,
    this.mass = kRingMass,
    this.radius = kRingRadius,
    this.drag = kDrag,
    this.elasticity = kElasticity,
    this.wallFriction = kWallFriction,
  });

  void applyForce(Offset f, double dt) {
    velocity += (f / mass) * dt;
  }

  void applyImpulse(Offset j) {
    velocity += j / mass;
  }

  void tick(double dt, Size bounds) {
    velocity = velocity * (1.0 - drag);
    position += velocity * dt;
    _bounceWalls(bounds);
  }

  void _bounceWalls(Size bounds) {
    double x = position.dx;
    double y = position.dy;
    double vx = velocity.dx;
    double vy = velocity.dy;

    if (x - radius < 0) {
      x = radius;
      vx = vx.abs() * elasticity;
      vy *= wallFriction;
    } else if (x + radius > bounds.width) {
      x = bounds.width - radius;
      vx = -vx.abs() * elasticity;
      vy *= wallFriction;
    }

    if (y - radius < 0) {
      y = radius;
      vy = vy.abs() * elasticity;
      vx *= wallFriction;
    } else if (y + radius > bounds.height) {
      y = bounds.height - radius;
      vy = -vy.abs() * elasticity;
      vx *= wallFriction;
    }

    position = Offset(x, y);
    velocity = Offset(vx, vy);
  }

  // Vrací sílu, kterou prst na prsten působí
  Offset fingerForce(Offset fingerPos) {
    final delta = fingerPos - position;
    final dist = delta.distance;
    final contactRadius = radius * kContactZone;
    if (dist > contactRadius) return Offset.zero;

    return delta.normalized * kStiffness * (1.0 - dist / contactRadius);
  }

  // Kolik remote prst brání pohybu (0–1)
  double calcResistance(Offset localForce, Offset remoteForce) {
    final localDist = localForce.distance;
    final remoteDist = remoteForce.distance;
    if (localDist < 0.001 || remoteDist < 0.001) return 0.0;
    final dot = localForce.dot(remoteForce);
    if (dot >= 0) return 0.0;
    return (-dot / (localDist * remoteDist + 0.001)).clamp(0.0, 1.0);
  }

  // Soft sync — host broadcastuje hint, guest lerp-uje
  void applySyncHint(Offset hintPos, Offset hintVel) {
    position = Offset.lerp(position, hintPos, kSyncLerp)!;
    velocity = Offset.lerp(velocity, hintVel, kSyncLerp)!;
  }
}
