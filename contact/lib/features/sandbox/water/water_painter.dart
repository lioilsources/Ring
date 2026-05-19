import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../game/physics/constants.dart';
import 'ripple.dart';

class WaterPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final List<WaterRipple> ripples;
  final ui.Image? faceLocal;
  final ui.Image? faceRemote;
  final ui.Image placeholder;

  WaterPainter({
    required this.shader,
    required this.time,
    required this.ripples,
    required this.faceLocal,
    required this.faceRemote,
    required this.placeholder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var i = 0;
    shader.setFloat(i++, size.width);
    shader.setFloat(i++, size.height);
    shader.setFloat(i++, time);

    final n = ripples.length > kMaxRipples ? kMaxRipples : ripples.length;
    shader.setFloat(i++, n.toDouble());
    for (var k = 0; k < kMaxRipples; k++) {
      if (k < n) {
        final r = ripples[k];
        shader.setFloat(i++, r.center.dx);
        shader.setFloat(i++, r.center.dy);
        shader.setFloat(i++, time - r.startTime);
        shader.setFloat(i++, r.strength);
      } else {
        shader.setFloat(i++, 0);
        shader.setFloat(i++, 0);
        shader.setFloat(i++, 0);
        shader.setFloat(i++, 0);
      }
    }
    shader.setFloat(i++, faceLocal != null ? 1.0 : 0.0);
    shader.setFloat(i++, faceRemote != null ? 1.0 : 0.0);

    // Samplers must always be bound, even when a face is absent.
    shader.setImageSampler(0, faceLocal ?? placeholder);
    shader.setImageSampler(1, faceRemote ?? placeholder);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(WaterPainter old) => true;
}
