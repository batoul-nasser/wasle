import 'package:flutter/material.dart';

import 'package:wasle/features/auth/data/app_auth_service.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  final AppAuthService _authService = AppAuthService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final route = await _authService.resolveInitialRoute();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF4F7FF),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1A56DB),
        ),
      ),
    );
  }
}
