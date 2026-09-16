import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../services/share_intent_handler.dart';
import 'settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // Catches screenshots sent in via the Android Share Sheet.
    _shareHandler.listen(_handleIncomingFile);
  }

  @override
  void dispose() {
    _shareHandler.dispose();
    super.dispose();
  }

  Future<void> _handleIncomingFile(File file) async {
    setState(() => _uploading = true);
    try {
      final roomId = await _storage.getRoomId();
      final mode = await _storage.getMode();
      final nickname = mode == 'team' ? await _storage.getNickname() : null;

      await _supabase.uploadScreenshot(
        imageFile: file,
        roomId: roomId!,
        uploaderName: nickname,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScreenBridge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
