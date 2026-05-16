import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/supabase_client.dart';

typedef FingerCallback = void Function(Offset pos, bool active, Offset? impulse);
typedef HintCallback = void Function(Offset pos, Offset vel);

class BroadcastService {
  RealtimeChannel? _channel;
  final String roomId;

  BroadcastService(this.roomId);

  void subscribe({
    required FingerCallback onRemoteFinger,
    required HintCallback onRingHint,
    VoidCallback? onPresenceJoin,
    VoidCallback? onPresenceLeave,
  }) {
    _channel = supabase
        .channel('game:$roomId')
        .onBroadcast(
          event: 'finger',
          callback: (payload) {
            final pos = Offset(
              (payload['x'] as num).toDouble(),
              (payload['y'] as num).toDouble(),
            );
            final active = payload['active'] as bool;
            Offset? impulse;
            if (payload['impulse'] != null) {
              impulse = Offset(
                (payload['impulse']['dx'] as num).toDouble(),
                (payload['impulse']['dy'] as num).toDouble(),
              );
            }
            onRemoteFinger(pos, active, impulse);
          },
        )
        .onBroadcast(
          event: 'ring_hint',
          callback: (payload) {
            final pos = Offset(
              (payload['rx'] as num).toDouble(),
              (payload['ry'] as num).toDouble(),
            );
            final vel = Offset(
              (payload['vx'] as num).toDouble(),
              (payload['vy'] as num).toDouble(),
            );
            onRingHint(pos, vel);
          },
        )
        .onPresenceJoin((payload) => onPresenceJoin?.call())
        .onPresenceLeave((payload) => onPresenceLeave?.call())
        .subscribe();
  }

  Future<void> sendFinger(Offset pos, bool active, {Offset? impulse}) async {
    final payload = <String, dynamic>{
      'x': pos.dx,
      'y': pos.dy,
      'active': active,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    if (impulse != null) {
      payload['impulse'] = {'dx': impulse.dx, 'dy': impulse.dy};
    }
    await _channel?.sendBroadcastMessage(event: 'finger', payload: payload);
  }

  Future<void> sendRingHint(Offset pos, Offset vel) async {
    await _channel?.sendBroadcastMessage(
      event: 'ring_hint',
      payload: {
        'rx': pos.dx,
        'ry': pos.dy,
        'vx': vel.dx,
        'vy': vel.dy,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> dispose() async {
    if (_channel != null) {
      await supabase.removeChannel(_channel!);
    }
  }
}
