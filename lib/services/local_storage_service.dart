import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's room setup locally so onboarding only happens once.
class LocalStorageService {
  static const _kRoomId = 'room_id';
  static const _kRoomCode = 'room_code';
  static const _kMode = 'mode'; // 'personal' or 'team'
  static const _kNickname = 'nickname';

  Future<void> saveRoomConfig({
    required String roomId,
    required String roomCode,
    required String mode,
    String? nickname,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRoomId, roomId);
    await prefs.setString(_kRoomCode, roomCode);
    await prefs.setString(_kMode, mode);
    if (nickname != null) await prefs.setString(_kNickname, nickname);
  }

  Future<bool> hasRoomConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kRoomId);
  }

  Future<String?> getRoomId() async =>
      (await SharedPreferences.getInstance()).getString(_kRoomId);

  Future<String?> getRoomCode() async =>
      (await SharedPreferences.getInstance()).getString(_kRoomCode);

  Future<String?> getMode() async =>
      (await SharedPreferences.getInstance()).getString(_kMode);

  Future<String?> getNickname() async =>
      (await SharedPreferences.getInstance()).getString(_kNickname);

  Future<void> updateNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNickname, nickname);
  }

  /// Used when switching modes from Settings — clears room binding so the
  /// onboarding flow can run again for the new mode.
  Future<void> clearRoomConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRoomId);
    await prefs.remove(_kRoomCode);
    await prefs.remove(_kMode);
    // Nickname is kept — no need to re-ask if they switch back to team mode.
  }
}
