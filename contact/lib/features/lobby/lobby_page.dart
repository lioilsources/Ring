import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../game/game_bloc.dart';
import 'room_service.dart';
import '../../shared/supabase_client.dart';

class LobbyPage extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const LobbyPage({super.key, required this.roomId, required this.isHost});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  StreamSubscription? _sub;
  bool _opponentJoined = false;

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      _sub = RoomService.watchRoom(widget.roomId).listen((room) {
        if (room['guest_id'] != null && !_opponentJoined) {
          setState(() => _opponentJoined = true);
          _startGame();
        }
      });
    } else {
      // Guest může rovnou začít
      _opponentJoined = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startGame());
    }
  }

  void _startGame() {
    final size = MediaQuery.of(context).size;
    context.read<GameBloc>().add(
          GameStarted(widget.roomId, widget.isHost, size),
        );
    context.go('/game', extra: {'roomId': widget.roomId, 'isHost': widget.isHost});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PulsingRing(),
              const SizedBox(height: 32),
              Text(
                widget.isHost ? 'Čekám na přítele…' : 'Připojuji se…',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingRing extends StatefulWidget {
  const _PulsingRing();

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 88 + _ctrl.value * 16,
        height: 88 + _ctrl.value * 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3 + _ctrl.value * 0.3),
            width: 3,
          ),
        ),
      ),
    );
  }
}
