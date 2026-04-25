import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class StartupGate extends StatefulWidget {
  final String? startupError;

  const StartupGate({super.key, this.startupError});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  final AuthService _authService = AuthService();
  StreamSubscription<AuthState>? _authSubscription;

  bool _isResolvingRoute = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    _errorText = widget.startupError;

    if (_errorText != null) return;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      _resolveAndNavigate();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveAndNavigate();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resolveAndNavigate() async {
    if (_isResolvingRoute || !mounted) return;

    _isResolvingRoute = true;

    try {
      final route = await _authService.resolveInitialRoute();

      debugPrint('STARTUP ROUTE = $route');

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, route);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorText = 'Startup failed: $error';
      });
    } finally {
      _isResolvingRoute = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorText != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'App configuration error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(_errorText!, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
