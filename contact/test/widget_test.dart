import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact/features/game/physics/ring_body.dart';
import 'package:contact/features/game/physics/physics_world.dart';
import 'package:contact/features/game/physics/flick_detector.dart';

void main() {
  const bounds = Size(400, 800);

  test('RingBody stays within bounds after ticks', () {
    final ring = RingBody();
    ring.velocity = const Offset(5000, 5000);
    for (var i = 0; i < 120; i++) {
      ring.tick(1 / 60, bounds);
    }
    expect(ring.position.dx, greaterThanOrEqualTo(ring.radius));
    expect(ring.position.dx, lessThanOrEqualTo(bounds.width - ring.radius));
    expect(ring.position.dy, greaterThanOrEqualTo(ring.radius));
    expect(ring.position.dy, lessThanOrEqualTo(bounds.height - ring.radius));
  });

  test('RingBody velocity decays with drag', () {
    final ring = RingBody();
    ring.velocity = const Offset(1000, 0);
    ring.tick(1 / 60, bounds);
    expect(ring.velocity.dx, lessThan(1000));
  });

  test('PhysicsWorld applies finger force in contact zone', () {
    final world = PhysicsWorld();
    world.init(bounds);
    final center = world.ring.position;
    world.setLocalFinger(center, true);
    final velBefore = world.ring.velocity.distance;
    world.tick(1 / 60);
    expect(world.ring.velocity.distance, greaterThanOrEqualTo(velBefore));
  });

  test('FlickDetector returns null below threshold', () {
    final detector = FlickDetector();
    const pos = Offset(100, 100);
    detector.update(pos, 1 / 60);
    final impulse = detector.update(const Offset(101, 100), 1 / 60);
    expect(impulse, isNull);
  });

  test('FlickDetector returns impulse above threshold', () {
    final detector = FlickDetector();
    detector.update(const Offset(0, 0), 1 / 60);
    final impulse = detector.update(const Offset(100, 0), 1 / 60);
    expect(impulse, isNotNull);
    expect(impulse!.dx, greaterThan(0));
  });
}
