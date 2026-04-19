import 'package:flutter/material.dart';
import '../../data/auth_service.dart';
import 'otp_verification_screen.dart';

class CompanySignUpScreen extends StatefulWidget {
  const CompanySignUpScreen({super.key});

  @override
  State<CompanySignUpScreen> createState() => _CompanySignUpScreenState();
}

class _CompanySignUpScreenState extends State<CompanySignUpScreen> {
  static const Color blue = Color(0xFF2F80FF);

  final AuthService _authService = AuthService();

  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController adminNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? errorText;
  bool isLoading = false;

  bool _isStrongPassword(String password) {
    final hasMinLength = password.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial =
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]]').hasMatch(password);

    return hasMinLength &&
        hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecial;
  }

  Future<void> _createCompanyAccount() async {
    final companyName = companyNameController.text.trim();
    final adminName = adminNameController.text.trim();
    final email = emailController.text.trim();
    final location = locationController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (companyName.isEmpty ||
        adminName.isEmpty ||
        email.isEmpty ||
        location.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        errorText = 'Please fill all fields';
      });
      return;
    }

    final emailValid = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
    if (!emailValid) {
      setState(() {
        errorText = 'Please enter a valid email';
      });
      return;
    }

    if (!_isStrongPassword(password)) {
      setState(() {
        errorText =
            'Password must be at least 8 chars and include upper, lower, number, and special character';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        errorText = 'Password and confirm password do not match';
      });
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      await _authService.sendOtp(
        email: email,
        shouldCreateUser: true,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            title: 'Verify Company Account',
            mode: OtpScreenMode.companySignup,
            fullName: adminName,
            companyName: companyName,
            location: location,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        errorText = e.toString();
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
    companyNameController.dispose();
    adminNameController.dispose();
    emailController.dispose();
    locationController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Sign Up'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: companyNameController,
              decoration: const InputDecoration(
                labelText: 'Company Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: adminNameController,
              decoration: const InputDecoration(
                labelText: 'Admin Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Company Location',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Strong password example: Wasle@123',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  errorText!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
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
                onPressed: isLoading ? null : _createCompanyAccount,
                child: Text(
                  isLoading ? 'Loading...' : 'Create Company Account',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
