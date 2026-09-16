import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _supabase = SupabaseService();
  final _storage = LocalStorageService();
  bool _loading = false;

  Future<void> _choosePersonal() async {
    setState(() => _loading = true);
    final room = await _supabase.createPersonalRoom();
    await _storage.saveRoomConfig(
      roomId: room['room_id']!,
      roomCode: room['room_code']!,
      mode: 'personal',
    );
    _goHome();
  }

  Future<void> _createTeam() async {
    final nickname = await _promptNickname();
    if (nickname == null) return;

    setState(() => _loading = true);
    final room = await _supabase.createTeamRoom();
    await _storage.saveRoomConfig(
      roomId: room['room_id']!,
      roomCode: room['room_code']!,
      mode: 'team',
      nickname: nickname,
    );

    if (mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Team created'),
          content: Text(
            'Share this code with your team:\n\n${room['room_code']}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
    _goHome();
  }

  Future<void> _joinTeam() async {
    final code = await _promptCode();
    if (code == null || code.isEmpty) return;
    final nickname = await _promptNickname();
    if (nickname == null) return;

    setState(() => _loading = true);
    try {
      final room = await _supabase.joinTeamRoom(code);
      await _storage.saveRoomConfig(
        roomId: room['room_id']!,
        roomCode: room['room_code']!,
        mode: 'team',
        nickname: nickname,
      );
      _goHome();
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room code not found. Check and try again.')),
        );
      }
    }
  }

  Future<String?> _promptNickname() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your nickname'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Zed'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptCode() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter team code'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. ZX7K9P'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.screenshot_monitor, size: 64),
              const SizedBox(height: 16),
              const Text(
                'How will you use ScreenBridge?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _choosePersonal,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Just me (Personal)'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _createTeam,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Create a team'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _joinTeam,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Join a team with a code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
