import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../game/physics/physics_world.dart';
import '../game/physics/ring_rotation.dart';
import '../game/rendering/torus_painter.dart';

class SandboxPage extends StatefulWidget {
  const SandboxPage({super.key});

  @override
  State<SandboxPage> createState() => _SandboxPageState();
}

class _SandboxPageState extends State<SandboxPage> with SingleTickerProviderStateMixin {
  PhysicsWorld? _world;
  final RingRotation _rotation = RingRotation();
  late Ticker _ticker;
  Duration _lastTime = Duration.zero;
  double _animTime = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
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

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = _world;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          if (world != null)
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => setState(() {
                world.localFingerPos = e.localPosition;
                world.localFingerActive = true;
              }),
              onPointerMove: (e) => setState(() {
                world.localFingerPos = e.localPosition;
              }),
              onPointerUp: (_) => setState(() {
                world.localFingerActive = false;
              }),
              onPointerCancel: (_) => setState(() {
                world.localFingerActive = false;
              }),
              child: CustomPaint(
                painter: TorusPainter(world, _rotation, _animTime),
                child: const SizedBox.expand(),
              ),
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
