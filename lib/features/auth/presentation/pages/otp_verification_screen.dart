import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String title;
  final AuthFlowMode mode;

  final String? fullName;
  final String? phone;
  final String? city;

  final String? companyName;
  final String? location;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.title,
    required this.mode,
    this.fullName,
    this.phone,
    this.city,
    this.companyName,
    this.location,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController otpController = TextEditingController();

  bool isLoading = false;
  String? errorText;

  Future<void> _verifyOtp() async {
    final token = otpController.text.trim();

    if (token.isEmpty) {
      setState(() => errorText = 'Please enter the OTP code');
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      final response = await _authService.verifyOtp(
        email: widget.email,
        token: token,
      );

      final userId = response.user?.id;
      if (userId == null) {
        throw Exception('User not found after OTP verification');
      }

      switch (widget.mode) {
        case AuthFlowMode.login:
          final route = await _authService.resolveInitialRoute();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
          break;

        case AuthFlowMode.driverSignup:
          await _authService.createDriverProfile(
            userId: userId,
            fullName: widget.fullName ?? '',
            phone: widget.phone ?? '',
            city: widget.city ?? '',
          );

          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/driver-dashboard',
            (_) => false,
          );
          break;

        case AuthFlowMode.companySignup:
          await _authService.createCompanyProfile(
            userId: userId,
            adminName: widget.fullName ?? '',
            companyName: widget.companyName ?? '',
            location: widget.location ?? '',
          );

          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/company-dashboard',
            (_) => false,
          );
          break;
      }
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
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: otpController,
              decoration: const InputDecoration(labelText: 'OTP Code'),
            ),
            const SizedBox(height: 16),
            if (errorText != null)
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : _verifyOtp,
              child: Text(isLoading ? 'Verifying...' : 'Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
