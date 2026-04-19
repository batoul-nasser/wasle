import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  print('URL: ${Env.supabaseUrl}');
  print('KEY: ${Env.supabaseAnonKey}');

  

  String? startupError;

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Allow production builds to rely on --dart-define without crashing on startup.
  }

  if (!Env.hasSupabaseConfig) {
    startupError =
        'Missing Supabase configuration. Add SUPABASE_URL and SUPABASE_ANON_KEY to .env '
        'or provide them with --dart-define.';
  } else {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
    } catch (error) {
      startupError = 'Failed to initialize Supabase: $error';
    }
  }

  runApp(WasleApp(startupError: startupError));
}
