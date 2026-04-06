import 'package:flutter/material.dart';
import 'package:wasle/app/router.dart';
import 'package:wasle/app/startup/startup_gate.dart';
import 'package:wasle/core/theme/app_theme.dart';
import 'package:wasle/core/ui/ui.dart';

class WasleApp extends StatelessWidget {
  const WasleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wasle',
      theme: AppTheme.lightTheme,
      home: const StartupGate(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
