import 'package:uuid/uuid.dart';
import '../../shared/supabase_client.dart';

class InviteService {
  static const _uuid = Uuid();

  // Vytvoří room + invite token, vrátí deep link
  static Future<String> createInviteLink(String fromUserId) async {
    final roomId = _uuid.v4();
    final token = _uuid.v4().replaceAll('-', '');
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    await supabase.from('rooms').insert({
      'id': roomId,
      'host_id': fromUserId,
    });

    await supabase.from('invites').insert({
      'token': token,
      'from_id': fromUserId,
      'room_id': roomId,
      'expires_at': expiresAt.toIso8601String(),
    });

    return 'contact.ol1n.com/invite/$token';
  }

  // Ověří token, vrátí room_id nebo null
  static Future<String?> redeemInvite(String token, String userId) async {
    final row = await supabase
        .from('invites')
        .select('room_id, expires_at, used')
        .eq('token', token)
        .maybeSingle();

    if (row == null) return null;
    if (row['used'] == true) return null;
    if (DateTime.parse(row['expires_at']).isBefore(DateTime.now())) return null;

    await supabase.from('invites').update({'used': true}).eq('token', token);

    await supabase.from('rooms').update({'guest_id': userId}).eq('id', row['room_id']);

    return row['room_id'] as String;
  }
}
