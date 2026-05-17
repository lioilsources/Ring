import 'dart:math';
import 'package:flutter/material.dart';
import '../physics/physics_world.dart';
import '../physics/constants.dart';
import '../physics/ring_rotation.dart';

class TorusPainter extends CustomPainter {
  final PhysicsWorld world;
  final RingRotation rotation;
  final double animTime;

  // Torus geometry
  static const int _nPhi = 32;   // segments around main ring
  static const int _nTheta = 16; // segments around tube
  static const double _majorR = 78.0; // major radius (3D units)
  static const double _tubeR = 15.0;  // tube radius
  // Perspective
  static const double _camDist = 280.0;
  static const double _focal = 450.0;
  // Idle spin (rad/s) — ring keeps moving so it always looks 3D
  static const double _idleSpeed = 0.5;
  // Light direction (normalized, in camera space — upper-left-front)
  static const double _lx = 0.408, _ly = -0.816, _lz = -0.408;

  const TorusPainter(this.world, this.rotation, this.animTime);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawWalls(canvas, size);
    _drawTorus(canvas);
    _drawFingers(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0A0F),
    );
  }

  void _drawWalls(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Paint()
        ..color = const Color(0xFF1E1E2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawTorus(Canvas canvas) {
    final center = world.ring.position;
    final ay = rotation.angleY + animTime * _idleSpeed;
    final ax = rotation.angleX;

    final cosAy = cos(ay), sinAy = sin(ay);
    final cosAx = cos(ax), sinAx = sin(ax);

    final faces = <_Face>[];

    for (var ip = 0; ip < _nPhi; ip++) {
      final phi0 = 2 * pi * ip / _nPhi;
      final phi1 = 2 * pi * (ip + 1) / _nPhi;

      for (var it = 0; it < _nTheta; it++) {
        final theta0 = 2 * pi * it / _nTheta;
        final theta1 = 2 * pi * (it + 1) / _nTheta;

        // Face normal at quad center (analytical)
        final phiC = phi0 + pi / _nPhi;
        final thetaC = theta0 + pi / _nTheta;
        final n = _normal(phiC, thetaC);
        final rn = _rotate(n, cosAy, sinAy, cosAx, sinAx);

        // Back-face culling: normal z > 0 means facing away from camera
        if (rn[2] > 0) continue;

        // Rotate and project 4 corners
        final pts = [
          _project(_rotate(_vertex(phi0, theta0), cosAy, sinAy, cosAx, sinAx), center),
          _project(_rotate(_vertex(phi1, theta0), cosAy, sinAy, cosAx, sinAx), center),
          _project(_rotate(_vertex(phi1, theta1), cosAy, sinAy, cosAx, sinAx), center),
          _project(_rotate(_vertex(phi0, theta1), cosAy, sinAy, cosAx, sinAx), center),
        ];

        // Average depth for painter's algorithm
        final avgZ = (_rotate(_vertex(phi0, theta0), cosAy, sinAy, cosAx, sinAx)[2] +
                      _rotate(_vertex(phi1, theta0), cosAy, sinAy, cosAx, sinAx)[2] +
                      _rotate(_vertex(phi1, theta1), cosAy, sinAy, cosAx, sinAx)[2] +
                      _rotate(_vertex(phi0, theta1), cosAy, sinAy, cosAx, sinAx)[2]) /
                     4;

        // Diffuse lighting
        final diffuse = (_lx * rn[0] + _ly * rn[1] + _lz * rn[2]).clamp(0.0, 1.0);

        faces.add(_Face(pts, avgZ, diffuse.toDouble()));
      }
    }

    // Sort back-to-front (painter's algorithm)
    faces.sort((a, b) => a.z.compareTo(b.z));

    final path = Path();
    for (final face in faces) {
      path.reset();
      path.moveTo(face.pts[0].dx, face.pts[0].dy);
      path.lineTo(face.pts[1].dx, face.pts[1].dy);
      path.lineTo(face.pts[2].dx, face.pts[2].dy);
      path.lineTo(face.pts[3].dx, face.pts[3].dy);
      path.close();
      canvas.drawPath(path, Paint()..color = _goldColor(face.diffuse));
    }
  }

  // Torus in XY plane, phi around Z axis
  List<double> _vertex(double phi, double theta) {
    final ct = cos(theta), st = sin(theta);
    final cp = cos(phi), sp = sin(phi);
    return [(_majorR + _tubeR * ct) * cp, (_majorR + _tubeR * ct) * sp, _tubeR * st];
  }

  List<double> _normal(double phi, double theta) {
    final ct = cos(theta), st = sin(theta);
    final cp = cos(phi), sp = sin(phi);
    return [ct * cp, ct * sp, st];
  }

  // Ry then Rx
  List<double> _rotate(List<double> p, double cy, double sy, double cx, double sx) {
    final x1 = p[0] * cy + p[2] * sy;
    final y1 = p[1];
    final z1 = -p[0] * sy + p[2] * cy;
    return [x1, y1 * cx - z1 * sx, y1 * sx + z1 * cx];
  }

  Offset _project(List<double> p, Offset center) {
    final scale = _focal / (_camDist + p[2]);
    return Offset(center.dx + p[0] * scale, center.dy + p[1] * scale);
  }

  Color _goldColor(double diffuse) {
    const shadow = Color(0xFF4A2800);
    const mid = Color(0xFFD4A843);
    const highlight = Color(0xFFFFEA8A);
    if (diffuse < 0.5) {
      return Color.lerp(shadow, mid, diffuse * 2)!;
    }
    return Color.lerp(mid, highlight, (diffuse - 0.5) * 2)!;
  }

  void _drawFingers(Canvas canvas) {
    if (world.localFingerActive && world.localFingerPos != null) {
      _drawFinger(canvas, world.localFingerPos!, isLocal: true);
    }
    if (world.remoteFingerActive && world.remoteFingerPos != null) {
      _drawFinger(canvas, world.remoteFingerPos!, isLocal: false);
    }
  }

  void _drawFinger(Canvas canvas, Offset pos, {required bool isLocal}) {
    final color = isLocal ? const Color(0xFF6C63FF) : const Color(0xFFFF6384);
    canvas.drawCircle(
      pos,
      kRingRadius * kContactZone,
      Paint()
        ..color = color.withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    canvas.drawCircle(pos, 10, Paint()..color = color.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(TorusPainter old) => true;
}

class _Face {
  final List<Offset> pts;
  final double z;
  final double diffuse;
  const _Face(this.pts, this.z, this.diffuse);
}
