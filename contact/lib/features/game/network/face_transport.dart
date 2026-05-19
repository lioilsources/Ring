import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/supabase_client.dart';

/// Periodic face still transport for the networked game.
///
/// Upload path is private bucket `faces` at `<roomId>/<userId>.jpg` (upsert).
/// The other player never gets read RLS — instead the uploader mints a
/// short-lived signed URL and broadcasts it over the existing realtime
/// channel; the receiver fetches the bytes with a plain HTTPS GET.
class FaceTransport {
  final String roomId;
  final String userId;
  FaceTransport(this.roomId, this.userId);

  static const String bucket = 'faces';

  String get _path => '$roomId/$userId.jpg';

  /// Uploads the JPEG and returns a signed URL valid for [ttlSeconds].
  Future<String?> upload(Uint8List jpeg, {int ttlSeconds = 120}) async {
    try {
      await supabase.storage.from(bucket).uploadBinary(
            _path,
            jpeg,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      return await supabase.storage
          .from(bucket)
          .createSignedUrl(_path, ttlSeconds);
    } catch (_) {
      return null;
    }
  }

  /// Downloads bytes from a signed URL (no extra http package; dart:io only).
  static Future<Uint8List?> download(String signedUrl) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(signedUrl));
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final builder = BytesBuilder();
      await for (final chunk in resp) {
        builder.add(chunk);
      }
      return builder.toBytes();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
