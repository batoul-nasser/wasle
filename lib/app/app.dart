import 'package:flutter/material.dart';
import 'package:wasle/app/router.dart';
import 'package:wasle/app/startup/startup_gate.dart';

class WasleApp extends StatelessWidget {
  const WasleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const StartupGate(),
    );
  }
}
