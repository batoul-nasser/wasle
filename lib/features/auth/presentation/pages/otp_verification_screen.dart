import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String title;
  final AuthFlowMode mode;
  final String? fullName;
  final String? phone;
  final String? city;
  final String? companyName;
  final String? location;
  final String? businessName;

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
    this.businessName,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 6;

  final AuthService _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();

  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  String _required(String? value, String fieldName) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      throw Exception('$fieldName is required');
    }
    return text;
  }

  String? _validateOtpInput(String otp) {
    if (otp.isEmpty) {
      return 'Please enter the verification code.';
    }

    if (!RegExp(r'^\d+$').hasMatch(otp)) {
      return 'OTP code must contain numbers only.';
    }

    if (otp.length != _otpLength) {
      return 'Please enter the full 6-digit verification code.';
    }

    return null;
  }

  void _goTo(String routeName) {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    final validationError = _validateOtpInput(otp);
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });

      final response = await _authService.verifyOtp(
        email: widget.email,
        token: otp,
      );

      final userId = response.user?.id ?? _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('User session not found after OTP verification');
      }

      switch (widget.mode) {
        case AuthFlowMode.driverSignup:
          await _authService.createDriverProfile(
            userId: userId,
            fullName: _required(widget.fullName, 'Full name'),
            phone: _required(widget.phone, 'Phone'),
            city: _required(widget.city, 'City'),
          );
          _goTo('/select-company');
          return;

        case AuthFlowMode.companySignup:
          await _authService.createCompanyProfile(
            userId: userId,
            adminName: _required(widget.fullName, 'Admin name'),
            companyName: _required(widget.companyName, 'Company name'),
            location: _required(widget.location, 'Location'),
          );
          _goTo('/waiting-approval');
          return;

        case AuthFlowMode.customerSignup:
          await _authService.createCustomerProfile(
            userId: userId,
            fullName: _required(widget.fullName, 'Full name'),
            phone: _required(widget.phone, 'Phone'),
          );
          _goTo('/customer-dashboard');
          return;

        case AuthFlowMode.merchantSignup:
          await _authService.createMerchantProfile(
            userId: userId,
            fullName: _required(widget.fullName, 'Full name'),
            phone: _required(widget.phone, 'Phone'),
            businessName: _required(widget.businessName, 'Business name'),
          );
          _goTo('/merchant-dashboard');
          return;

        case AuthFlowMode.login:
          final route = await _authService.resolveInitialRoute();
          _goTo(route);
          return;
      }
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_verify', error, stackTrace);
      setState(() {
        _errorText = AuthErrorMapper.map(
          error,
          context: AuthErrorContext.otpVerification,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    try {
      setState(() => _errorText = null);

      await _authService.sendOtp(
        email: widget.email,
        shouldCreateUser: widget.mode != AuthFlowMode.login,
      );

      _startTimer();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code sent successfully.')),
      );
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_resend', error, stackTrace);
      setState(() {
        _errorText = AuthErrorMapper.map(
          error,
          context: AuthErrorContext.otpRequest,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeText = '00:${_secondsRemaining.toString().padLeft(2, '0')}';

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
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_otpLength),
                    ],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'OTP Code',
                      hintText: 'Enter verification code',
                      prefixIcon: Icon(Icons.password_rounded),
                      counterText: '',
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
            if (_errorText != null)
              Text(
                _errorText!,
                style: AppTextStyles.body.copyWith(color: AppColors.danger),
              ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Verify OTP',
              icon: Icons.verified_outlined,
              isLoading: _isLoading,
              onPressed: _verifyOtp,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_secondsRemaining == 0)
              SecondaryButton(
                label: 'Resend Code',
                icon: Icons.refresh_rounded,
                onPressed: _isLoading ? null : _resendOtp,
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
