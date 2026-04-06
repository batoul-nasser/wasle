import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/pages/otp_verification_screen.dart';

class DriverSignUpScreen extends StatefulWidget {
  const DriverSignUpScreen({super.key});

  @override
  State<DriverSignUpScreen> createState() => _DriverSignUpScreenState();
}

class _DriverSignUpScreenState extends State<DriverSignUpScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  bool isLoading = false;
  String? errorText;

  Future<void> _continue() async {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final city = cityController.text.trim();

    if (fullName.isEmpty || email.isEmpty || phone.isEmpty || city.isEmpty) {
      setState(() => errorText = 'Please fill all fields');
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
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 16),
            if (errorText != null)
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : _continue,
              child: Text(isLoading ? 'Loading...' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
