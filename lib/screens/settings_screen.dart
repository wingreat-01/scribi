import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = LocalStorageService();
  String? _mode;
  String? _roomCode;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await _storage.getMode();
    final code = await _storage.getRoomCode();
    final nickname = await _storage.getNickname();
    setState(() {
      _mode = mode;
      _roomCode = code;
      _nickname = nickname;
    });
  }

  Future<void> _switchMode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch mode?'),
        content: const Text(
          'This will disconnect from your current room. You can create or join a different one next.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storage.clearRoomConfig();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Mode'),
              subtitle: Text(_mode == 'team' ? 'Team' : 'Personal'),
            ),
            if (_mode == 'team') ...[
              ListTile(
                title: const Text('Room code'),
                subtitle: Text(_roomCode ?? '—'),
              ),
              ListTile(
                title: const Text('Your nickname'),
                subtitle: Text(_nickname ?? '—'),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _switchMode,
              child: const Text('Switch mode / room'),
            ),
          ],
        ),
      ),
    );
  }
}
