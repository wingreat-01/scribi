import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import 'home_screen.dart';

/// Join-only entry screen. Mobile never creates rooms — only joins ones
/// created on desktop, via a typed code or a scanned QR code.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _supabase = SupabaseService();
  final _storage = LocalStorageService();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _join(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final room = await _supabase.joinRoom(code);
      await _storage.saveRoom(
        roomId: room['id'] as String,
        roomCode: room['code'] as String,
        expiresAt: DateTime.parse(room['expires_at'] as String),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on RoomNotFoundException {
      setState(() => _error = 'Room not found. Check the code and try again.');
    } on RoomExpiredException {
      setState(() => _error = 'This room has expired.');
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanQr() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (scanned != null) {
      _codeController.text = scanned;
      _join(scanned);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Join a Room',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the code shown on desktop, or scan its QR code.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 2),
                decoration: const InputDecoration(
                  hintText: 'ZX7K9P',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (_loading) const CircularProgressIndicator(),
              if (!_loading) ...[
                ElevatedButton(
                  onPressed: () => _join(_codeController.text),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Join with code'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _scanQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR code'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final _controller = MobileScannerController();
  // onDetect can fire more than once for the same code before the
  // screen finishes popping -- without this, a second frame decoded a
  // few milliseconds later tries to pop the (already popping) route
  // again with a different value.
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;
    _handled = true;

    // Stop the camera before popping. Disposing this screen while the
    // camera preview is still mid-frame is what left the *next*
    // screen rendering solid black -- the texture mobile_scanner was
    // drawing into hadn't been released yet. Stopping first lets the
    // native camera session close cleanly.
    await _controller.stop();
    if (mounted) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan room QR code')),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
