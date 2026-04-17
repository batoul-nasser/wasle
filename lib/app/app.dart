import 'package:flutter/material.dart';
import 'package:wasle/app/router.dart';
import 'package:wasle/app/startup/startup_gate.dart';

class WasleApp extends StatelessWidget {
  final String? startupError;

  const WasleApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: StartupGate(startupError: startupError),
    );
  }
}
