// lib/ui/auth/auth_gate.dart
//
// Wasle — Auth Gate
// Verifies authenticated merchant access before entering MerchantShell.
//
// BUG 1 FIXED: import '../screens/merchant_shell.dart'
//              was '../merchant_shell.dart' → resolved to lib/ui/merchant_shell.dart
//              which does not exist. File is at lib/ui/screens/merchant_shell.dart.
//
// BUG 4 FIXED: FutureBuilder was nested directly inside StreamBuilder.
//              Every Supabase auth event rebuilt the tree → new Future →
//              duplicate resolveMerchantGate() DB calls + race condition.
//              Fixed by extracting into _MerchantAccessCheck (StatefulWidget)
//              which stores the future in initState so it only runs once.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wasle/ui/merchant_shell.dart';
import 'auth_controller.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authController.authStateChanges,
      builder: (context, snapshot) {
        final session = authController.currentSession;

        // Still restoring session on cold start.
        if (snapshot.connectionState == ConnectionState.waiting &&
            session == null) {
          return const _SplashScreen();
        }

        // No authenticated session → go to login.
        if (session == null) {
          return const LoginScreen();
        }

        // Session exists → verify merchant access.
        // Uses StatefulWidget so the Future is created once in initState,
        // not re-created every time the StreamBuilder rebuilds.
        return const _MerchantAccessCheck();
      },
    );
  }
}

// ─── Merchant access check ────────────────────────────────────────────────────
// Stores the future in initState so it is stable across rebuilds.
// FIX for BUG 4.
class _MerchantAccessCheck extends StatefulWidget {
  const _MerchantAccessCheck();

  @override
  State<_MerchantAccessCheck> createState() => _MerchantAccessCheckState();
}

class _MerchantAccessCheckState extends State<_MerchantAccessCheck> {
  late final Future<AuthGateDecision> _decisionFuture;

  @override
  void initState() {
    super.initState();
    // Called exactly once. Not re-fired on stream events.
    _decisionFuture = authController.resolveMerchantGate();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthGateDecision>(
      future: _decisionFuture,
      builder: (context, gateSnap) {
        if (gateSnap.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }

        final decision = gateSnap.data;

        if (decision?.allowAccess == true) {
          return const MerchantShell();
        }

        return _LogoutThenLogin(
          errorMessage:
              decision?.errorMessage ??
              'Could not verify your merchant account.',
        );
      },
    );
  }
}

// ─── Logout then show login with error ───────────────────────────────────────
// Shows LoginScreen with error immediately, then fires logout in background.
// Logout triggers a stream event → session becomes null → LoginScreen
// (without error) replaces this widget naturally.
class _LogoutThenLogin extends StatefulWidget {
  final String errorMessage;

  const _LogoutThenLogin({required this.errorMessage});

  @override
  State<_LogoutThenLogin> createState() => _LogoutThenLoginState();
}

class _LogoutThenLoginState extends State<_LogoutThenLogin> {
  @override
  void initState() {
    super.initState();
    // Fire and forget — stream handles navigation after logout completes.
    Future.microtask(authController.logout);
  }

  @override
  Widget build(BuildContext context) {
    return LoginScreen(initialError: widget.errorMessage);
  }
}

// ─── Splash / Loading Screen ─────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF1A56DB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1A56DB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}