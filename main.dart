import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/local_storage_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

// TODO: replace with your actual Supabase project values (Step 1).
const supabaseUrl = 'https://mjrhxthswsncdvnujuxb.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qcmh4dGhzd3NuY2R2bnVqdXhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk1MTE5NzcsImV4cCI6MjEwNTA4Nzk3N30.LN-OEhv-sO-20_dbNCI9wpVwusWJufNzmaIvcueMy_4';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ScreenBridgeApp());
}

class ScreenBridgeApp extends StatelessWidget {
  const ScreenBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScreenBridge',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const _StartupRouter(),
    );
  }
}

/// Decides whether to show onboarding or go straight to Home, based on
/// whether a room is already saved locally.
class _StartupRouter extends StatelessWidget {
  const _StartupRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: LocalStorageService().hasRoomConfig(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const HomeScreen() : const OnboardingScreen();
      },
    );
  }
}
