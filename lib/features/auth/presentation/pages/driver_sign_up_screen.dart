import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';
import 'otp_verification_screen.dart';

class DriverSignUpScreen extends StatefulWidget {
  const DriverSignUpScreen({super.key});

  @override
  State<DriverSignUpScreen> createState() => _DriverSignUpScreenState();
}

class _DriverSignUpScreenState extends State<DriverSignUpScreen> {
  static const Color blue = Color(0xFF2F80FF);

  final AuthService _authService = AuthService();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String? errorText;
  bool isLoading = false;

  bool _containsDigitsOnly(String phone) {
    return RegExp(r'^[0-9]+$').hasMatch(phone);
  }

  bool _isValidPhoneLength(String phone) {
    return phone.length >= 7 && phone.length <= 15;
  }

  bool _isStrongPassword(String password) {
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    return password.length >= 8 &&
        hasLower &&
        hasUpper &&
        hasDigit &&
        hasSpecial;
  }

  Future<void> _createAccount() async {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final city = cityController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (fullName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        city.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => errorText = 'Please fill all fields');
      return;
    }

    final emailValid = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
    if (!emailValid) {
      setState(() => errorText = 'Please enter a valid email address.');
      return;
    }

    if (!_containsDigitsOnly(phone)) {
      setState(() => errorText = 'Phone number must contain digits only');
      return;
    }

    if (!_isValidPhoneLength(phone)) {
      setState(() => errorText = 'Phone number must be between 7 and 15 digits');
      return;
    }

    if (!_isStrongPassword(password)) {
      setState(
        () => errorText =
            'Password must be 8+ chars and include uppercase, lowercase, number, and special character.',
      );
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
            title: 'Verify Driver Account',
            mode: AuthFlowMode.driverSignup,
            fullName: fullName,
            phone: phone,
            city: city,
          ),
        ),
      );
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_request_driver_signup', error, stackTrace);
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
    emailController.dispose();
    phoneController.dispose();
    cityController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'City / Location'),
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
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading ? null : _createAccount,
                child: Text(isLoading ? 'Loading...' : 'Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
