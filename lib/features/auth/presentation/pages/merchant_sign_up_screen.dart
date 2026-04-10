import 'package:flutter/material.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/pages/otp_verification_screen.dart';

class MerchantSignUpScreen extends StatefulWidget {
  const MerchantSignUpScreen({super.key});

  @override
  State<MerchantSignUpScreen> createState() => _MerchantSignUpScreenState();
}

class _MerchantSignUpScreenState extends State<MerchantSignUpScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  bool isLoading = false;
  String? errorText;

  Future<void> _sendOtp() async {
    final fullName = fullNameController.text.trim();
    final businessName = businessNameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();

    if (fullName.isEmpty ||
        businessName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty) {
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
            title: 'Verify Merchant Account',
            mode: AuthFlowMode.merchantSignup,
            fullName: fullName,
            phone: phone,
            businessName: businessName,
          ),
        ),
      );
    } catch (e) {
      setState(() => errorText = 'Failed to send OTP: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    businessNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ListView(
          children: [
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: businessNameController,
              decoration: const InputDecoration(labelText: 'Business Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (errorText != null)
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Send OTP',
              onPressed: isLoading ? null : _sendOtp,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
