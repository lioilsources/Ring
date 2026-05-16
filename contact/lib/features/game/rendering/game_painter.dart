import 'dart:math';
import 'package:flutter/material.dart';
import '../physics/physics_world.dart';
import '../physics/constants.dart';

class GamePainter extends CustomPainter {
  final PhysicsWorld world;
  final double animTime;

  GamePainter(this.world, this.animTime);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawWalls(canvas, size);
    if (world.remoteFingerActive && world.remoteFingerPos != null) {
      _drawFinger(canvas, world.remoteFingerPos!, isLocal: false);
    }
    if (world.localFingerActive && world.localFingerPos != null) {
      _drawFinger(canvas, world.localFingerPos!, isLocal: true);
    }
    _drawRing(canvas, world.ring.position);
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0A0F),
    );
  }

  void _drawWalls(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E1E2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      paint,
    );
  }

  void _drawFinger(Canvas canvas, Offset pos, {required bool isLocal}) {
    final color = isLocal ? const Color(0xFF6C63FF) : const Color(0xFFFF6384);

    // Glow
    canvas.drawCircle(
      pos,
      kRingRadius * kContactZone,
      Paint()
        ..color = color.withValues(alpha:0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Dot
    canvas.drawCircle(pos, 10, Paint()..color = color.withValues(alpha:0.9));
  }

  void _drawRing(Canvas canvas, Offset pos) {
    // Pulsující glow — intensity řízena animTime
    final pulse = 0.5 + 0.5 * sin(animTime * 2.0);
    canvas.drawCircle(
      pos,
      kRingRadius + 8,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha:0.05 + 0.04 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Prsten
    canvas.drawCircle(
      pos,
      kRingRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}
