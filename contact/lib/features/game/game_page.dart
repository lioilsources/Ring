import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'game_bloc.dart';
import 'rendering/game_painter.dart';

class GamePage extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const GamePage({super.key, required this.roomId, required this.isHost});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
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
    context.read<GameBloc>().add(GameTick(dt.clamp(0.001, 0.05), size));
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    context.read<GameBloc>().add(GameStopped());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        if (!state.running || state.world == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0F),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          body: Stack(
            children: [
              _GameCanvas(world: state.world!, animTime: _animTime),
              if (!state.opponentOnline)
                const _WaitingOverlay(),
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                child: _StatusDot(online: state.opponentOnline),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GameCanvas extends StatelessWidget {
  final dynamic world;
  final double animTime;

  const _GameCanvas({required this.world, required this.animTime});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => context.read<GameBloc>().add(
            LocalFingerUpdate(e.localPosition, true),
          ),
      onPointerMove: (e) => context.read<GameBloc>().add(
            LocalFingerUpdate(e.localPosition, true),
          ),
      onPointerUp: (_) => context.read<GameBloc>().add(
            const LocalFingerUpdate(null, false),
          ),
      onPointerCancel: (_) => context.read<GameBloc>().add(
            const LocalFingerUpdate(null, false),
          ),
      child: CustomPaint(
        painter: GamePainter(world, animTime),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF6C63FF),
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'Čekám na protihráče…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool online;

  const _StatusDot({required this.online});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? const Color(0xFF4CAF50) : Colors.white24,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          online ? 'Online' : 'Offline',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}
