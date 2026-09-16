import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomNotFoundException implements Exception {}
class RoomExpiredException implements Exception {}

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Joins an existing room by its short code. Mobile never creates rooms —
  /// only desktop does — so this is the only entry point here.
  Future<Map<String, dynamic>> joinRoom(String code) async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('code', code.trim().toUpperCase())
        .maybeSingle();

    if (response == null) throw RoomNotFoundException();

    final expiresAt = DateTime.parse(response['expires_at'] as String);
    if (DateTime.now().isAfter(expiresAt)) throw RoomExpiredException();

    return response;
  }

  /// Uploads an image to Storage and records it in `screenshots`.
  Future<void> uploadScreenshot({
    required File imageFile,
    required String roomId,
  }) async {
    final path = '$roomId/${DateTime.now().millisecondsSinceEpoch}.png';

    await _client.storage.from('screenshots').upload(path, imageFile);
    final imageUrl = _client.storage.from('screenshots').getPublicUrl(path);

    await _client.from('screenshots').insert({
      'room_id': roomId,
      'image_url': imageUrl,
      'storage_path': path,
    });
  }
}
