// File: lib/features/auth/presentation/pages/otp_verification_screen.dart

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
  final VehicleType? vehicleType;
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
    this.vehicleType,
    this.companyName,
    this.location,
    this.businessName,
  }) : assert(
         mode != AuthFlowMode.driverSignup || vehicleType != null,
         'Driver signup requires a selected vehicle type.',
       );

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 8;

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
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _resendOtp() async {
    try {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
      await _authService.sendOtp(
        email: widget.email,
        shouldCreateUser: widget.mode != AuthFlowMode.login,
      );
      _startTimer();
    } catch (e, st) {
      AuthErrorMapper.log('otp_resend', e, st);
      setState(
        () => _errorText = AuthErrorMapper.map(
          e,
          context: AuthErrorContext.otpRequest,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();
    if (token.isEmpty || token.length != _otpLength) {
      setState(() => _errorText = 'Please enter the $_otpLength-digit code');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });

      final response = await _authService.verifyOtp(
        email: widget.email,
        token: token,
      );

      final userId = response.user?.id;
      if (userId == null) {
        setState(() => _errorText = 'Verification failed. Please try again.');
        return;
      }

      switch (widget.mode) {
        case AuthFlowMode.driverSignup:
          await _authService.createDriverProfile(
            userId: userId,
            fullName: widget.fullName ?? '',
            phone: widget.phone ?? '',
            city: widget.city ?? '',
            vehicleType: widget.vehicleType!,
          );
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/waiting-approval',
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

        case AuthFlowMode.customerSignup:
          await _authService.createCustomerProfile(
            userId: userId,
            fullName: widget.fullName ?? '',
            phone: widget.phone ?? '',
          );
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/customer-dashboard',
            (_) => false,
          );
          break;

        case AuthFlowMode.merchantSignup:
          await _authService.createMerchantProfile(
            userId: userId,
            fullName: widget.fullName ?? '',
            phone: widget.phone ?? '',
            businessName: widget.businessName ?? '',
          );
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/merchant-dashboard',
            (_) => false,
          );
          break;

        case AuthFlowMode.login:
          if (!mounted) return;
          final route = await _authService.resolveInitialRoute();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
          break;
      }
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_verify', error, stackTrace);
      if (!mounted) return;
      setState(
        () => _errorText = AuthErrorMapper.map(
          error,
          context: AuthErrorContext.otpVerification,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsRemaining <= 0 && !_isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Check your email', style: AppTextStyles.heading3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'We sent a $_otpLength-digit code to ${widget.email}',
                  style: AppTextStyles.bodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: _otpLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2,
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              hintText: '........',
              counterText: '',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            onSubmitted: (_) => _verifyOtp(),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_errorText != null) ...[
            Text(
              _errorText!,
              style: AppTextStyles.body.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          PrimaryButton(
            label: 'Verify Code',
            icon: Icons.check_circle_outline,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _verifyOtp,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: canResend
                ? TextButton.icon(
                    onPressed: _resendOtp,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Resend Code'),
                  )
                : Text(
                    'Resend available in ${_secondsRemaining}s',
                    style: AppTextStyles.bodyMuted,
                  ),
          ),
        ],
      ),
    );
  }
}
