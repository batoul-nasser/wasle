import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/auth_service.dart';
import 'company_dashboard_screen.dart';
import 'driver_dashboard_screen.dart';
import 'rejected_screen.dart';
import 'select_company_screen.dart';
import 'waiting_approval_screen.dart';

enum OtpScreenMode {
  login,
  driverSignup,
  companySignup,
}

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String title;
  final OtpScreenMode mode;
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

  int secondsRemaining = 60;
  Timer? timer;
  bool isLoading = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    secondsRemaining = 60;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining == 0) {
        t.cancel();
      } else {
        setState(() {
          secondsRemaining--;
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.isEmpty) {
      setState(() => errorText = 'Please enter the OTP code');
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      print('STEP 1: verifyOtp started');

      final response = await _authService.verifyOtp(
        email: widget.email,
        token: otp,
      );

      print('STEP 2: OTP verified');

      final userId = response.user?.id ?? _authService.currentUser?.id;
      print('STEP 3: userId = $userId');

      if (userId == null) {
        throw Exception('User session not found after OTP verification');
      }

      if (widget.mode == OtpScreenMode.driverSignup) {
        print('STEP 4: creating driver profile...');

        await _authService.createDriverProfile(
          userId: userId,
          fullName: widget.fullName!,
          phone: widget.phone!,
          city: widget.city!,
        );

        print('STEP 5: driver profile created');

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const SelectCompanyScreen(),
          ),
          (route) => false,
        );
        return;
      }

      if (widget.mode == OtpScreenMode.companySignup) {
        print('STEP 4: creating company profile...');

        await _authService.createCompanyProfile(
          userId: userId,
          adminName: widget.fullName!,
          companyName: widget.companyName!,
          location: widget.location!,
        );

        print('STEP 5: company profile created');

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const WaitingApprovalScreen(),
          ),
          (route) => false,
        );
        return;
      }

      print('STEP 6: login mode success');

      final profile = await _authService.getCurrentProfile();

      if (profile == null) {
        throw Exception('Profile not found');
      }

      final role = profile['role']?.toString();

      if (!mounted) return;

      if (role == 'company_admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const CompanyDashboardScreen(),
          ),
          (route) => false,
        );
        return;
      }

      if (role == 'driver') {
        final status = await _authService.checkDriverStatus();

        if (!mounted) return;

        if (status == 'pending') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const WaitingApprovalScreen(),
            ),
            (route) => false,
          );
          return;
        }

        if (status == 'approved') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const DriverDashboardScreen(),
            ),
            (route) => false,
          );
          return;
        }

        if (status == 'rejected') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const RejectedScreen(),
            ),
            (route) => false,
          );
          return;
        }

        throw Exception('Unknown driver status');
      }

      throw Exception('Unknown role');
    } catch (e, st) {
      print('OTP VERIFY ERROR: $e');
      print(st);

      setState(() => errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    try {
      setState(() => errorText = null);

      await _authService.sendOtp(
        email: widget.email,
        shouldCreateUser: widget.mode == OtpScreenMode.driverSignup ||
            widget.mode == OtpScreenMode.companySignup,
      );

      _startTimer();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent again')),
      );
    } catch (e) {
      setState(() => errorText = e.toString());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeText = '00:${secondsRemaining.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email Verification', style: AppTextStyles.title),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Enter the code sent to ${widget.email}',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            InfoCard(
              child: Column(
                children: [
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'OTP Code',
                      hintText: 'Enter verification code',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        'Expires in ',
                        style: AppTextStyles.bodyMuted,
                      ),
                      Text(
                        timeText,
                        style: AppTextStyles.title.copyWith(color: AppColors.primary),
                      ),
                    ],
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
              label: 'Verify OTP',
              icon: Icons.verified_outlined,
              isLoading: isLoading,
              onPressed: _verifyOtp,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (secondsRemaining == 0)
              SecondaryButton(
                label: 'Resend Code',
                icon: Icons.refresh_rounded,
                onPressed: _resendOtp,
              )
            else
              Text(
                'You can request a new code once the timer reaches zero.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMuted,
              ),
          ],
        ),
      ),
    );
  }
}
