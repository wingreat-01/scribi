import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

  /// Creates a new 'personal' room. Returns the room's id and generated code.
  Future<Map<String, String>> createPersonalRoom() async {
    return _createRoom(mode: 'personal');
  }

  /// Creates a new 'team' room with a short shareable code.
  Future<Map<String, String>> createTeamRoom({String? name}) async {
    return _createRoom(mode: 'team', name: name);
  }

  Future<Map<String, String>> _createRoom({
    required String mode,
    String? name,
  }) async {
    final code = _generateShortCode();
    final response = await _client
        .from('rooms')
        .insert({'code': code, 'mode': mode, 'name': name})
        .select()
        .single();

    return {'room_id': response['id'] as String, 'room_code': code};
  }

  /// Looks up an existing team room by its shared code.
  /// Throws if the code doesn't exist.
  Future<Map<String, String>> joinTeamRoom(String code) async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('code', code.trim().toUpperCase())
        .single();

    return {
      'room_id': response['id'] as String,
      'room_code': response['code'] as String,
    };
  }

  String _generateShortCode() {
    // Short, easy to read/share aloud — 6 uppercase alphanumeric chars.
    final raw = _uuid.v4().replaceAll('-', '').toUpperCase();
    return raw.substring(0, 6);
  }

  /// Uploads an image file to Storage and inserts a matching row in
  /// `screenshots` linked to the given room.
  Future<void> uploadScreenshot({
    required File imageFile,
    required String roomId,
    String? uploaderName,
  }) async {
    final fileName =
        '${roomId}_${DateTime.now().millisecondsSinceEpoch}.png';

    await _client.storage.from('screenshots').upload(fileName, imageFile);

    final imageUrl =
        _client.storage.from('screenshots').getPublicUrl(fileName);

    await _client.from('screenshots').insert({
      'room_id': roomId,
      'image_url': imageUrl,
      'uploader_name': uploaderName,
    });
  }
}
