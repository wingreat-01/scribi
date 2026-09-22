import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gal/gal.dart';
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
  String? _roomId;
  DateTime? _expiresAt;
  Timer? _expiryTimer;

  // The two-way gallery: everything uploaded to this room, from
  // either device, newest first. Loaded once on entry, then kept live
  // via _subscribeToGallery so a desktop upload shows up here without
  // the person needing to reopen the app.
  List<Map<String, dynamic>> _screenshots = [];
  bool _loadingGallery = true;
  RealtimeChannel? _channel;

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
    _channel?.unsubscribe();
    _shareHandler.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoom() async {
    final room = await _storage.getRoom();
    if (room != null) {
      setState(() {
        _roomCode = room['room_code'];
        _roomId = room['room_id'];
        _expiresAt = DateTime.tryParse(room['expires_at']!);
      });
      if (_roomId != null) {
        await _loadScreenshots(_roomId!);
        _subscribeToGallery(_roomId!);
      }
    }
  }

  Future<void> _loadScreenshots(String roomId) async {
    try {
      final rows = await Supabase.instance.client
          .from('screenshots')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(20);
      if (!mounted) return;
      setState(() {
        _screenshots = List<Map<String, dynamic>>.from(rows as List);
        _loadingGallery = false;
      });
    } catch (e) {
      debugPrint('loadScreenshots failed: $e');
      if (mounted) setState(() => _loadingGallery = false);
    }
  }

  void _subscribeToGallery(String roomId) {
    // Mirrors index.html's subscribeToRoom() -- same channel naming,
    // same filter -- so a screenshot uploaded from either device
    // reaches both sides through the same INSERT event.
    _channel = Supabase.instance.client
        .channel('screenshots-$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'screenshots',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() => _screenshots.insert(0, payload.newRecord));
          },
        )
        .subscribe();
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
      debugPrint('uploadScreenshot failed: $e');
      setState(() => _lastStatus = 'Upload failed — try again');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _showUploadOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source);
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

  Future<void> _downloadScreenshot(Map<String, dynamic> row) async {
    final path = row['storage_path'] as String?;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This screenshot has no saved file to download.')),
      );
      return;
    }
    try {
      final bytes = await Supabase.instance.client.storage.from('screenshots').download(path);
      await Gal.putImageBytes(bytes, name: 'screenbridge_${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your gallery.')),
      );
    } catch (e) {
      debugPrint('download failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save — try again.')),
      );
    }
  }

  void _openFullImage(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(row['image_url'] as String),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Save to gallery',
                  onPressed: () => _downloadScreenshot(row),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery() {
    if (_loadingGallery) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_screenshots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No screenshots yet.\nUpload one from either device to see it here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _screenshots.length,
      itemBuilder: (context, index) {
        final row = _screenshots[index];
        return GestureDetector(
          onTap: () => _openFullImage(row),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  row['image_url'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image_outlined)),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.download, color: Colors.white, size: 18),
                      tooltip: 'Save to gallery',
                      onPressed: () => _downloadScreenshot(row),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        leading: IconButton(
          icon: const Icon(Icons.upload_outlined),
          tooltip: 'Upload screenshot',
          onPressed: _uploading ? null : _showUploadOptions,
        ),
        title: Text(_roomCode != null ? 'Room $_roomCode' : 'ScreenBridge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Leave room',
            onPressed: _leaveRoom,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                if (_expiresAt != null) Chip(label: Text(_timeLeftLabel())),
                if (_uploading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: CircularProgressIndicator(),
                  ),
                if (!_uploading && _lastStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_lastStatus!, style: const TextStyle(fontSize: 15)),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildGallery()),
        ],
      ),
    );
  }
}
