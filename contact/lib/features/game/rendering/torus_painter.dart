import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Vertices, VertexMode;
import 'package:flutter/material.dart';
import '../physics/physics_world.dart';
import '../physics/constants.dart';
import '../physics/ring_rotation.dart';

class TorusPainter extends CustomPainter {
  final PhysicsWorld world;
  final RingRotation rotation;
  final double animTime;

  // Torus geometry (higher tessellation — drawVertices makes this cheap)
  static const int _nPhi = 48; // segments around main ring
  static const int _nTheta = 24; // segments around tube
  static const double _majorR = 78.0; // major radius (3D units)
  static const double _tubeR = 15.0; // tube radius
  // Perspective
  static const double _camDist = 280.0;
  static const double _focal = 450.0;
  // Idle spin (rad/s) — ring keeps moving so it always looks 3D
  static const double _idleSpeed = 0.5;
  // Light direction (normalized, in camera space — upper-left-front)
  static const double _lx = 0.408, _ly = -0.816, _lz = -0.408;

  const TorusPainter(this.world, this.rotation, this.animTime);

  // --- Precomputed base geometry (constant; cos/sin of phi/theta) -----------
  static List<double>? _basePos; // [vi*3 + {0,1,2}]
  static List<double>? _baseNrm;

  static void _ensureBase() {
    if (_basePos != null) return;
    final pos = List<double>.filled(_nPhi * _nTheta * 3, 0);
    final nrm = List<double>.filled(_nPhi * _nTheta * 3, 0);
    for (var ip = 0; ip < _nPhi; ip++) {
      final phi = 2 * pi * ip / _nPhi;
      final cp = cos(phi), sp = sin(phi);
      for (var it = 0; it < _nTheta; it++) {
        final theta = 2 * pi * it / _nTheta;
        final ct = cos(theta), st = sin(theta);
        final i = (ip * _nTheta + it) * 3;
        pos[i] = (_majorR + _tubeR * ct) * cp;
        pos[i + 1] = (_majorR + _tubeR * ct) * sp;
        pos[i + 2] = _tubeR * st;
        nrm[i] = ct * cp;
        nrm[i + 1] = ct * sp;
        nrm[i + 2] = st;
      }
    }
    _basePos = pos;
    _baseNrm = nrm;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawWalls(canvas, size);
    _drawContactShadow(canvas);
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

  // Soft contact shadow grounds the ring in the scene (light is upper-left,
  // so the shadow falls toward lower-right).
  void _drawContactShadow(Canvas canvas) {
    final c = world.ring.position;
    final r = _focal / _camDist * _majorR; // approx projected footprint
    final rect = Rect.fromCenter(
      center: Offset(c.dx + r * 0.10, c.dy + r * 0.16),
      width: r * 2.05,
      height: r * 1.55,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
  }

  void _drawTorus(Canvas canvas) {
    _ensureBase();
    final basePos = _basePos!;
    final baseNrm = _baseNrm!;

    final center = world.ring.position;
    final ay = rotation.angleY + animTime * _idleSpeed;
    final ax = rotation.angleX;
    final cosAy = cos(ay), sinAy = sin(ay);
    final cosAx = cos(ax), sinAx = sin(ax);

    // View vector (surface -> camera) is constant in camera space.
    const vx = 0.0, vy = 0.0, vz = -1.0;
    // Half vector for Blinn-Phong (L and V constant -> compute once).
    var hx = _lx + vx, hy = _ly + vy, hz = _lz + vz;
    final hl = sqrt(hx * hx + hy * hy + hz * hz);
    hx /= hl;
    hy /= hl;
    hz /= hl;

    final nv = _nPhi * _nTheta;
    final sx = Float32List(nv); // projected screen x
    final sy = Float32List(nv); // projected screen y
    final sz = Float32List(nv); // rotated depth (for sorting)
    final col = Int32List(nv); // packed ARGB per vertex

    for (var v = 0; v < nv; v++) {
      final pi = v * 3;
      final px = basePos[pi], py = basePos[pi + 1], pz = basePos[pi + 2];
      // Rotate position (Ry then Rx)
      final rx1 = px * cosAy + pz * sinAy;
      final rz1 = -px * sinAy + pz * cosAy;
      final rpx = rx1;
      final rpy = py * cosAx - rz1 * sinAx;
      final rpz = py * sinAx + rz1 * cosAx;
      // Rotate normal (same rotation)
      final nx = baseNrm[pi], ny = baseNrm[pi + 1], nz = baseNrm[pi + 2];
      final nx1 = nx * cosAy + nz * sinAy;
      final nz1 = -nx * sinAy + nz * cosAy;
      final rnx = nx1;
      final rny = ny * cosAx - nz1 * sinAx;
      final rnz = ny * sinAx + nz1 * cosAx;

      // Project
      final scale = _focal / (_camDist + rpz);
      sx[v] = center.dx + rpx * scale;
      sy[v] = center.dy + rpy * scale;
      sz[v] = rpz;

      col[v] = _shade(rnx, rny, rnz, hx, hy, hz);
    }

    // Build triangle list, quads sorted back-to-front (painter's algorithm —
    // drawVertices has no depth buffer, so emit order defines occlusion).
    final quads = <_Quad>[];
    for (var ip = 0; ip < _nPhi; ip++) {
      final ip1 = (ip + 1) % _nPhi;
      for (var it = 0; it < _nTheta; it++) {
        final it1 = (it + 1) % _nTheta;
        final a = ip * _nTheta + it;
        final b = ip1 * _nTheta + it;
        final cc = ip1 * _nTheta + it1;
        final d = ip * _nTheta + it1;
        // Back-face cull using the rotated quad-center normal.
        final pi = ((ip * _nTheta + it)) * 3;
        // Cheap cull: average the 4 rotated normals' z via depth proxy.
        final avgZ = (sz[a] + sz[b] + sz[cc] + sz[d]) * 0.25;
        // Recompute center normal z for cull (reuse base, rotate just z-part).
        final nx = baseNrm[pi], ny = baseNrm[pi + 1], nz = baseNrm[pi + 2];
        final nz1 = -nx * sinAy + nz * cosAy;
        final rnz = ny * sinAx + nz1 * cosAx;
        if (rnz > 0.0) continue; // facing away (keep silhouette for rim)
        quads.add(_Quad(a, b, cc, d, avgZ));
      }
    }
    quads.sort((p, q) => q.z.compareTo(p.z)); // far first

    final n = quads.length;
    final positions = Float32List(n * 12); // 6 verts * 2 (xy) per quad
    final colors = Int32List(n * 6);
    var pp = 0, cpos = 0;
    for (final q in quads) {
      // tri 1: a,b,c   tri 2: a,c,d  (unrolled to avoid per-quad allocation)
      final a = q.a, b = q.b, c = q.c, d = q.d;
      positions[pp++] = sx[a];
      positions[pp++] = sy[a];
      colors[cpos++] = col[a];
      positions[pp++] = sx[b];
      positions[pp++] = sy[b];
      colors[cpos++] = col[b];
      positions[pp++] = sx[c];
      positions[pp++] = sy[c];
      colors[cpos++] = col[c];
      positions[pp++] = sx[a];
      positions[pp++] = sy[a];
      colors[cpos++] = col[a];
      positions[pp++] = sx[c];
      positions[pp++] = sy[c];
      colors[cpos++] = col[c];
      positions[pp++] = sx[d];
      positions[pp++] = sy[d];
      colors[cpos++] = col[d];
    }

    final vertices = Vertices.raw(
      VertexMode.triangles,
      positions,
      colors: colors,
    );
    canvas.drawVertices(
      vertices,
      BlendMode.srcOver, // opaque per-vertex colors -> shows lit colors
      Paint()..isAntiAlias = true,
    );
  }

  // Per-vertex shading: gold albedo + ambient/diffuse + matcap fake
  // environment reflection + Blinn-Phong specular + Fresnel rim.
  int _shade(
      double nx, double ny, double nz, double hx, double hy, double hz) {
    // Diffuse
    var nl = (_lx * nx + _ly * ny + _lz * nz);
    if (nl < 0) nl = 0;
    const ambient = 0.20;
    final shade = ambient + (1 - ambient) * nl;

    // Gold base ramp
    var br = 0.0, bg = 0.0, bb = 0.0;
    if (shade < 0.45) {
      final t = shade / 0.45;
      br = _lerp(0x32, 0x8A, t);
      bg = _lerp(0x1B, 0x52, t);
      bb = _lerp(0x02, 0x12, t);
    } else if (shade < 0.78) {
      final t = (shade - 0.45) / 0.33;
      br = _lerp(0x8A, 0xDD, t);
      bg = _lerp(0x52, 0xAE, t);
      bb = _lerp(0x12, 0x3C, t);
    } else {
      final t = (shade - 0.78) / 0.22;
      br = _lerp(0xDD, 0xFF, t);
      bg = _lerp(0xAE, 0xF0, t);
      bb = _lerp(0x3C, 0xCE, t);
    }

    // Matcap-style fake environment reflection (sample by screen-space normal).
    final ey = -ny * 0.5 + 0.5; // 0 bottom .. 1 top
    // studio gradient: warm bright top, deep bronze bottom
    final er = _lerp(0x24, 0xFF, ey);
    final eg = _lerp(0x16, 0xEC, ey);
    final eb = _lerp(0x04, 0xC0, ey);
    // soft hotspot toward upper-left (matches key light)
    final dx = nx + 0.45, dy = ny - 0.45;
    var hot = 1.0 - (dx * dx + dy * dy) * 1.3;
    if (hot < 0) hot = 0;
    hot = hot * hot; // tighten

    // Metal: blend body with environment reflection.
    const refl = 0.42;
    var r = br * (1 - refl) + er * refl + 0xFF * hot * 0.55;
    var g = bg * (1 - refl) + eg * refl + 0xF6 * hot * 0.55;
    var b = bb * (1 - refl) + eb * refl + 0xD8 * hot * 0.55;

    // Blinn-Phong specular (tight, white-gold)
    var nh = nx * hx + ny * hy + nz * hz;
    if (nh < 0) nh = 0;
    final spec = pow(nh, 46).toDouble() * 235.0;
    r += spec;
    g += spec * 0.96;
    b += spec * 0.80;

    // Fresnel rim (bright at the silhouette where nz -> 0 for visible faces)
    var rim = 1.0 + nz; // visible faces have nz < 0
    if (rim < 0) rim = 0;
    rim = rim * rim * rim; // pow 3
    r += rim * 70;
    g += rim * 60;
    b += rim * 30;

    return 0xFF000000 |
        (_clamp255(r) << 16) |
        (_clamp255(g) << 8) |
        _clamp255(b);
  }

  static double _lerp(int a, int b, double t) => a + (b - a) * t;

  static int _clamp255(double v) {
    final i = v.toInt();
    if (i < 0) return 0;
    if (i > 255) return 255;
    return i;
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

class _Quad {
  final int a, b, c, d;
  final double z;
  const _Quad(this.a, this.b, this.c, this.d, this.z);
}
