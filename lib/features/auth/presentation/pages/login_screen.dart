import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? errorText;
  bool isLoading = false;

  static final RegExp _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  Future<void> _loginWithPassword() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    final emailError = _validateEmail(email);
    if (emailError != null) {
      setState(() => errorText = emailError);
      return;
    }

    if (password.isEmpty) {
      setState(() => errorText = 'Please enter your password.');
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      await _authService.signInWithPassword(
        email: email,
        password: password,
      );

      final route = await _authService.resolveInitialRoute();
      if (route == '/welcome') {
        await _authService.signOut();
        if (!mounted) return;
        setState(() {
          errorText = 'No account setup found for this user. Please sign up first.';
        });
        return;
      }

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } catch (error, stackTrace) {
      AuthErrorMapper.log('password_login', error, stackTrace);
      setState(() {
        errorText = AuthErrorMapper.map(
          error,
          context: AuthErrorContext.passwordLogin,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithOtp() async {
    final email = emailController.text.trim();

    final emailError = _validateEmail(email);
    if (emailError != null) {
      setState(() => errorText = emailError);
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      await _authService.sendOtp(
        email: email,
        shouldCreateUser: false,
      );

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
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_request_login', error, stackTrace);
      setState(() {
        errorText = AuthErrorMapper.map(
          error,
          context: AuthErrorContext.otpRequest,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
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
      appBar: AppBar(
        title: const Text('Log In'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.lock_outline, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: AppTextStyles.heading2.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Log in to continue to your driver workspace.',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            InfoCard(
              child: Column(
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'name@company.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (errorText != null)
              Text(
                errorText!,
                style: AppTextStyles.body.copyWith(color: AppColors.danger),
              ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Log In',
              icon: Icons.login_rounded,
              isLoading: isLoading,
              onPressed: _loginWithPassword,
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Log In with OTP',
              icon: Icons.sms_outlined,
              onPressed: isLoading ? null : _loginWithOtp,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Use your account password or request a one-time code by email.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}