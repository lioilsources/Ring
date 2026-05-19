import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../game/physics/physics_world.dart';
import '../game/physics/ring_rotation.dart';
import '../game/physics/constants.dart';
import '../game/rendering/torus_painter.dart';
import 'water/ripple.dart';
import 'water/water_painter.dart';
import 'water/face_camera_service.dart';

class SandboxPage extends StatefulWidget {
  const SandboxPage({super.key});

  @override
  State<SandboxPage> createState() => _SandboxPageState();
}

class _SandboxPageState extends State<SandboxPage>
    with SingleTickerProviderStateMixin {
  PhysicsWorld? _world;
  final RingRotation _rotation = RingRotation();
  late Ticker _ticker;
  Duration _lastTime = Duration.zero;
  double _animTime = 0.0;

  final RippleField _ripples = RippleField();
  ui.FragmentShader? _waterShader;
  ui.Image? _placeholder;
  ui.Image? _faceImage;
  FaceCameraService? _camera;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _initWater();
  }

  Future<void> _initWater() async {
    final program = await ui.FragmentProgram.fromAsset('shaders/water.frag');
    final placeholder = await _makePlaceholder();
    if (!mounted) return;
    setState(() {
      _waterShader = program.fragmentShader();
      _placeholder = placeholder;
    });

    _camera = FaceCameraService((image, _) {
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _faceImage?.dispose();
        _faceImage = image;
      });
    });
    await _camera!.start(
      Duration(milliseconds: (kFaceUpdateInterval * 1000).round()),
    );
  }

  Future<ui.Image> _makePlaceholder() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0x00000000),
    );
    return recorder.endRecording().toImage(1, 1);
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTime == Duration.zero
        ? 0.016
        : (elapsed - _lastTime).inMicroseconds / 1e6;
    _lastTime = elapsed;
    _animTime += dt;

    final size = MediaQuery.of(context).size;
    _world ??= PhysicsWorld(size);
    final world = _world!;

    world.tick(dt.clamp(0.001, 0.05), size);

    _rotation.applyVelocity(world.ring.velocity);
    final impulse = world.pendingImpulse;
    if (impulse != null) _rotation.applyImpulse(impulse);
    _rotation.tick(dt.clamp(0.001, 0.05));

    _ripples.prune(_animTime);

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _camera?.dispose();
    _waterShader?.dispose();
    _placeholder?.dispose();
    _faceImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = _world;
    final shader = _waterShader;
    final placeholder = _placeholder;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          if (shader != null && placeholder != null)
            Positioned.fill(
              child: CustomPaint(
                painter: WaterPainter(
                  shader: shader,
                  time: _animTime,
                  ripples: _ripples.ripples,
                  faceLocal: _faceImage,
                  // Sandbox has no opponent — loop the local face into the
                  // remote slot so the reflection path is visible.
                  faceRemote: _faceImage,
                  placeholder: placeholder,
                ),
              ),
            ),
          if (world != null)
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => setState(() {
                world.localFingerPos = e.localPosition;
                world.localFingerActive = true;
                _ripples.spawn(e.localPosition, _animTime);
              }),
              onPointerMove: (e) => setState(() {
                world.localFingerPos = e.localPosition;
                _ripples.spawn(e.localPosition, _animTime);
              }),
              onPointerUp: (_) => setState(() {
                world.localFingerActive = false;
              }),
              onPointerCancel: (_) => setState(() {
                world.localFingerActive = false;
              }),
              child: CustomPaint(
                painter: TorusPainter(
                  world,
                  _rotation,
                  _animTime,
                  drawEnvironment: false,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          if (_camera != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: const _CameraDot(),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'SANDBOX',
                style: TextStyle(
                  color: Colors.white12,
                  fontSize: 11,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Subtle indicator that the front camera is active (honesty, not a toggle).
class _CameraDot extends StatelessWidget {
  const _CameraDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6384).withValues(alpha: 0.75),
        shape: BoxShape.circle,
      ),
    );
  }
}
