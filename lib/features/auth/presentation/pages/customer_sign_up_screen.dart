import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/pages/otp_verification_screen.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';

class CustomerSignUpScreen extends StatefulWidget {
  const CustomerSignUpScreen({super.key});

  @override
  State<CustomerSignUpScreen> createState() => _CustomerSignUpScreenState();
}

class _CustomerSignUpScreenState extends State<CustomerSignUpScreen> {
  final AuthService _authService = AuthService();
  static final RegExp _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  String? errorText;

  Future<void> _sendOtp() async {
    final fullName = fullNameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (fullName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => errorText = 'Please fill all fields');
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      setState(() => errorText = 'Please enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      setState(() => errorText = 'Password must be at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => errorText = 'Password and confirm password do not match.');
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      await _authService.sendOtp(email: email, shouldCreateUser: true);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            title: 'Verify Customer Account',
            mode: AuthFlowMode.customerSignup,
            fullName: fullName,
            phone: phone,
          ),
        ),
      );
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_request_customer_signup', error, stackTrace);
      setState(
        () => errorText = AuthErrorMapper.map(
          error,
          context: AuthErrorContext.otpRequest,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
            const SizedBox(height: 16),
            if (errorText != null)
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : _sendOtp,
              child: Text(isLoading ? 'Sending...' : 'Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
