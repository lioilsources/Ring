import '../../shared/supabase_client.dart';

class RoomService {
  // Sleduje room — vrátí stream který emituje jakmile se přidá guest
  static Stream<Map<String, dynamic>> watchRoom(String roomId) {
    return supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) => rows.first);
  }
}
