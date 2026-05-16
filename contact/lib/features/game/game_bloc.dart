import 'dart:async';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'physics/physics_world.dart';
import 'network/broadcast_service.dart';
import 'network/sync_service.dart';
import '../../shared/haptic_engine.dart';

// --- Events ---
abstract class GameEvent extends Equatable {
  const GameEvent();
  @override
  List<Object?> get props => [];
}

class GameStarted extends GameEvent {
  final String roomId;
  final bool isHost;
  final Size bounds;
  const GameStarted(this.roomId, this.isHost, this.bounds);
  @override
  List<Object?> get props => [roomId, isHost];
}

class GameTick extends GameEvent {
  final double dt;
  final Size bounds;
  const GameTick(this.dt, this.bounds);
  @override
  List<Object?> get props => [];
}

class LocalFingerUpdate extends GameEvent {
  final Offset? pos;
  final bool active;
  const LocalFingerUpdate(this.pos, this.active);
  @override
  List<Object?> get props => [pos, active];
}

class RemoteFingerReceived extends GameEvent {
  final Offset pos;
  final bool active;
  final Offset? impulse;
  const RemoteFingerReceived(this.pos, this.active, this.impulse);
  @override
  List<Object?> get props => [];
}

class RingHintReceived extends GameEvent {
  final Offset pos;
  final Offset vel;
  const RingHintReceived(this.pos, this.vel);
  @override
  List<Object?> get props => [];
}

class OpponentConnected extends GameEvent {}
class OpponentDisconnected extends GameEvent {}
class GameStopped extends GameEvent {}

// --- State ---
class GameState extends Equatable {
  final PhysicsWorld? world;
  final bool opponentOnline;
  final bool running;

  const GameState({
    this.world,
    this.opponentOnline = false,
    this.running = false,
  });

  GameState copyWith({PhysicsWorld? world, bool? opponentOnline, bool? running}) {
    return GameState(
      world: world ?? this.world,
      opponentOnline: opponentOnline ?? this.opponentOnline,
      running: running ?? this.running,
    );
  }

  @override
  List<Object?> get props => [opponentOnline, running];
}

// --- Bloc ---
class GameBloc extends Bloc<GameEvent, GameState> {
  BroadcastService? _broadcast;
  SyncService? _sync;

  GameBloc() : super(const GameState()) {
    on<GameStarted>(_onStarted);
    on<GameTick>(_onTick);
    on<LocalFingerUpdate>(_onLocalFinger);
    on<RemoteFingerReceived>(_onRemoteFinger);
    on<RingHintReceived>(_onRingHint);
    on<OpponentConnected>(_onOpponentConnected);
    on<OpponentDisconnected>(_onOpponentDisconnected);
    on<GameStopped>(_onStopped);
  }

  Future<void> _onStarted(GameStarted event, Emitter<GameState> emit) async {
    final world = PhysicsWorld(event.bounds);
    _broadcast = BroadcastService(event.roomId);
    _sync = SyncService(broadcast: _broadcast!, world: world);

    _broadcast!.subscribe(
      onRemoteFinger: (pos, active, impulse) {
        add(RemoteFingerReceived(pos, active, impulse));
      },
      onRingHint: (pos, vel) => add(RingHintReceived(pos, vel)),
      onPresenceJoin: () => add(OpponentConnected()),
      onPresenceLeave: () => add(OpponentDisconnected()),
    );

    if (event.isHost) _sync!.startAsHost();

    emit(state.copyWith(world: world, running: true));
  }

  void _onTick(GameTick event, Emitter<GameState> emit) {
    final world = state.world;
    if (world == null) return;

    world.tick(event.dt, event.bounds);

    // Haptics
    HapticEngine.tickResistance(world.lastResistance);

    // Broadcast local finger
    if (world.localFingerPos != null) {
      _broadcast?.sendFinger(
        world.localFingerPos!,
        world.localFingerActive,
        impulse: world.pendingImpulse,
      );
      if (world.pendingImpulse != null) HapticEngine.flick();
    }

    emit(state.copyWith(world: world));
  }

  void _onLocalFinger(LocalFingerUpdate event, Emitter<GameState> emit) {
    final world = state.world;
    if (world == null) return;
    world.localFingerPos = event.pos;
    world.localFingerActive = event.active;
  }

  void _onRemoteFinger(RemoteFingerReceived event, Emitter<GameState> emit) {
    final world = state.world;
    if (world == null) return;
    world.remoteFingerPos = event.pos;
    world.remoteFingerActive = event.active;
    if (event.impulse != null) world.applyRemoteImpulse(event.impulse!);
  }

  void _onRingHint(RingHintReceived event, Emitter<GameState> emit) {
    _sync?.applyHint(event.pos, event.vel);
  }

  void _onOpponentConnected(OpponentConnected event, Emitter<GameState> emit) {
    HapticEngine.connect();
    emit(state.copyWith(opponentOnline: true));
  }

  void _onOpponentDisconnected(OpponentDisconnected event, Emitter<GameState> emit) {
    HapticEngine.disconnect();
    emit(state.copyWith(opponentOnline: false));
  }

  Future<void> _onStopped(GameStopped event, Emitter<GameState> emit) async {
    _sync?.dispose();
    await _broadcast?.dispose();
    emit(const GameState());
  }

  @override
  Future<void> close() async {
    _sync?.dispose();
    await _broadcast?.dispose();
    return super.close();
  }
}
