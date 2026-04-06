import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/pages/otp_verification_screen.dart';

class CompanySignUpScreen extends StatefulWidget {
  const CompanySignUpScreen({super.key});

  @override
  State<CompanySignUpScreen> createState() => _CompanySignUpScreenState();
}

class _CompanySignUpScreenState extends State<CompanySignUpScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController adminNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  bool isLoading = false;
  String? errorText;

  Future<void> _continue() async {
    final adminName = adminNameController.text.trim();
    final email = emailController.text.trim();
    final companyName = companyNameController.text.trim();
    final location = locationController.text.trim();

    if (adminName.isEmpty ||
        email.isEmpty ||
        companyName.isEmpty ||
        location.isEmpty) {
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
            title: 'Verify Company Account',
            mode: AuthFlowMode.companySignup,
            fullName: adminName,
            companyName: companyName,
            location: location,
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
    adminNameController.dispose();
    emailController.dispose();
    companyNameController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: adminNameController,
              decoration: const InputDecoration(labelText: 'Admin Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: companyNameController,
              decoration: const InputDecoration(labelText: 'Company Name'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Location'),
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
