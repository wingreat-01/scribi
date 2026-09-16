import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../services/share_intent_handler.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = SupabaseService();
  final _storage = LocalStorageService();
  final _shareHandler = ShareIntentHandler();
  final _picker = ImagePicker();

  bool _uploading = false;
  String? _lastStatus;
  String? _roomCode;
  DateTime? _expiresAt;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _loadRoom();
    _shareHandler.listen(_handleIncomingFile);
    // Check every 30s whether the room has expired while the screen is open.
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkExpiry());
  }

  @override
  void dispose() {
    _shareHandler.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoom() async {
    final room = await _storage.getRoom();
    if (room != null) {
      setState(() {
        _roomCode = room['room_code'];
        _expiresAt = DateTime.tryParse(room['expires_at']!);
      });
    }
  }

  void _checkExpiry() {
    if (_expiresAt != null && DateTime.now().isAfter(_expiresAt!)) {
      _leaveExpiredRoom();
    }
  }

  Future<void> _leaveExpiredRoom() async {
    await _storage.clearRoom();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room expired.')),
    );
  }

  Future<void> _handleIncomingFile(File file) async {
    final room = await _storage.getRoom();
    if (room == null) return;

    final expiresAt = DateTime.tryParse(room['expires_at']!);
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      _leaveExpiredRoom();
      return;
    }

    setState(() {
      _uploading = true;
      _lastStatus = null;
    });
    try {
      await _supabase.uploadScreenshot(imageFile: file, roomId: room['room_id']!);
      setState(() => _lastStatus = 'Synced ✅');
    } catch (e) {
      setState(() => _lastStatus = 'Upload failed — try again');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await _handleIncomingFile(File(picked.path));
    }
  }

  Future<void> _leaveRoom() async {
    await _storage.clearRoom();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  String _timeLeftLabel() {
    if (_expiresAt == null) return '';
    final remaining = _expiresAt!.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    final mins = remaining.inMinutes;
    return mins < 1 ? 'Expiring soon' : '$mins min left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_roomCode != null ? 'Room $_roomCode' : 'ScreenBridge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Leave room',
            onPressed: _leaveRoom,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_expiresAt != null)
                Chip(label: Text(_timeLeftLabel())),
              const SizedBox(height: 16),
              if (_uploading) const CircularProgressIndicator(),
              if (!_uploading && _lastStatus != null)
                Text(_lastStatus!, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 32),
              const Text(
                'Share a screenshot to this app,\nor pick one below.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _uploading ? null : _pickFromGallery,
                icon: const Icon(Icons.image),
                label: const Text('Pick Screenshot'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
