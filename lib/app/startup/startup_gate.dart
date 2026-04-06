import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      print('STARTUP: bootstrap started');

      final route = await _authService.resolveInitialRoute();

      print('STARTUP: resolved route = $route');

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, route);
    } catch (e, st) {
      print('STARTUP ERROR: $e');
      print(st);

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
