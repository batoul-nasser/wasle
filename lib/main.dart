// lib/main.dart
//
// Wasle — Main Entry Point
//
// supabase_flutter v2.x handles deep links internally.
// No extra packages needed. Just add the intent-filter to AndroidManifest.xml
// and ask the Supabase project owner to add wasle://login-callback
// to the allowed Redirect URLs list.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';
import 'merchant_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    // Deep link handling is built into supabase_flutter v2.
    // The SDK automatically intercepts wasle://login-callback,
    // reads the token from the URL, and confirms the session.
    // No manual setup needed here.
  );

  runApp(const MerchantApp());
}