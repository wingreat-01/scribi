import 'package:shared_preferences/shared_preferences.dart';

/// Persists the currently-joined room locally. Rooms are temporary, so
/// this is intentionally minimal — no mode, no nickname, no accounts.
class LocalStorageService {
  static const _kRoomId = 'room_id';
  static const _kRoomCode = 'room_code';
  static const _kExpiresAt = 'expires_at';

  Future<void> saveRoom({
    required String roomId,
    required String roomCode,
    required DateTime expiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRoomId, roomId);
    await prefs.setString(_kRoomCode, roomCode);
    await prefs.setString(_kExpiresAt, expiresAt.toIso8601String());
  }

  Future<Map<String, String>?> getRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final roomId = prefs.getString(_kRoomId);
    final roomCode = prefs.getString(_kRoomCode);
    final expiresAt = prefs.getString(_kExpiresAt);
    if (roomId == null || roomCode == null || expiresAt == null) return null;
    return {'room_id': roomId, 'room_code': roomCode, 'expires_at': expiresAt};
  }

  /// True if a room is saved AND it hasn't expired yet.
  Future<bool> hasActiveRoom() async {
    final room = await getRoom();
    if (room == null) return false;
    final expiresAt = DateTime.tryParse(room['expires_at']!);
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt);
  }

  Future<void> clearRoom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRoomId);
    await prefs.remove(_kRoomCode);
    await prefs.remove(_kExpiresAt);
  }
}
