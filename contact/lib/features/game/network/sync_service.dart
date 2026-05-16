import 'dart:async';
import 'dart:ui';
import '../physics/physics_world.dart';
import '../physics/constants.dart';
import 'broadcast_service.dart';

// Hostitel broadcastuje ring_hint každých kSyncInterval sekund
class SyncService {
  final BroadcastService broadcast;
  final PhysicsWorld world;
  Timer? _timer;

  SyncService({required this.broadcast, required this.world});

  void startAsHost() {
    _timer = Timer.periodic(
      Duration(milliseconds: (kSyncInterval * 1000).round()),
      (_) => broadcast.sendRingHint(world.ring.position, world.ring.velocity),
    );
  }

  void applyHint(Offset pos, Offset vel) {
    world.applySyncHint(pos, vel);
  }

  void dispose() => _timer?.cancel();
}
