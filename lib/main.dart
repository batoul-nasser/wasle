import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  runApp(const WasleApp());
}
