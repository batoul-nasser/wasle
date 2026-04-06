import 'package:flutter/material.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/pages/otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String? errorText;

  Future<void> _loginWithPassword() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorText = 'Please enter email and password');
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      await _authService.signInWithPassword(email: email, password: password);

      final route = await _authService.resolveInitialRoute();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
    } catch (e) {
      setState(() => errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loginWithOtp() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => errorText = 'Please enter your email');
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      await _authService.sendOtp(email: email, shouldCreateUser: false);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            title: 'Login with OTP',
            mode: AuthFlowMode.login,
          ),
        ),
      );
    } catch (e) {
      setState(() => errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.md),
            if (errorText != null)
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: isLoading ? 'Loading...' : 'Login',
              onPressed: isLoading ? null : _loginWithPassword,
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: isLoading ? 'Please wait...' : 'Login with OTP',
              onPressed: isLoading ? null : _loginWithOtp,
            ),
          ],
        ),
      ),
    );
  }
}
