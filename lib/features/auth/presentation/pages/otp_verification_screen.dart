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
  final String? signupPassword;
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
    this.signupPassword,
    this.companyName,
    this.location,
    this.businessName,
  }) : assert(
         mode != AuthFlowMode.driverSignup || vehicleType != null,
         'Driver signup requires a selected vehicle type.',
       ),
       assert(
         mode != AuthFlowMode.driverSignup ||
             (signupPassword != null && signupPassword != ''),
         'Driver signup requires a password.',
       );

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();

  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isLoading = false;
  String? _errorText;

  bool get _hasValidSignupContext {
    if (widget.mode == AuthFlowMode.login) return true;

    switch (widget.mode) {
      case AuthFlowMode.driverSignup:
        return widget.fullName != null &&
            widget.fullName!.trim().isNotEmpty &&
            widget.phone != null &&
            widget.phone!.trim().isNotEmpty &&
            widget.city != null &&
            widget.city!.trim().isNotEmpty &&
            widget.vehicleType != null &&
            widget.signupPassword != null &&
            widget.signupPassword!.isNotEmpty;
      case AuthFlowMode.companySignup:
        return widget.fullName != null &&
            widget.fullName!.trim().isNotEmpty &&
            widget.companyName != null &&
            widget.companyName!.trim().isNotEmpty &&
            widget.location != null &&
            widget.location!.trim().isNotEmpty;
      case AuthFlowMode.customerSignup:
        return widget.fullName != null &&
            widget.fullName!.trim().isNotEmpty &&
            widget.phone != null &&
            widget.phone!.trim().isNotEmpty;
      case AuthFlowMode.merchantSignup:
        return widget.fullName != null &&
            widget.fullName!.trim().isNotEmpty &&
            widget.phone != null &&
            widget.phone!.trim().isNotEmpty &&
            widget.businessName != null &&
            widget.businessName!.trim().isNotEmpty;
      case AuthFlowMode.login:
        return true;
    }
  }

  String get _invalidSessionMessage {
    if (widget.mode == AuthFlowMode.login) {
      return 'This login code request is no longer valid. Please start again.';
    }
    return 'This signup request is no longer valid. Please start signup again.';
  }

  int get _otpLength {
    switch (widget.mode) {
      case AuthFlowMode.driverSignup:
        return 8;
      case AuthFlowMode.login:
      case AuthFlowMode.companySignup:
      case AuthFlowMode.customerSignup:
      case AuthFlowMode.merchantSignup:
        return 6;
    }
  }

  @override
  void initState() {
    super.initState();
    _otpController.clear();
    if (!_hasValidSignupContext) {
      _errorText = _invalidSessionMessage;
      return;
    }
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
    if (!_hasValidSignupContext) {
      setState(() => _errorText = _invalidSessionMessage);
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
      if (widget.mode == AuthFlowMode.login) {
        await _authService.requestLoginOtp(email: widget.email);
      } else if (widget.mode == AuthFlowMode.driverSignup) {
        await _authService.resendDriverSignupOtpCode(email: widget.email);
      } else {
        await _authService.resendSignupOtp(email: widget.email);
      }
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
    if (!_hasValidSignupContext) {
      setState(() => _errorText = _invalidSessionMessage);
      return;
    }

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

      if (widget.mode == AuthFlowMode.driverSignup) {
        final response = await _authService.verifyDriverSignupOtpCode(
          email: widget.email,
          token: token,
        );
        final userId = response.user?.id;
        if (userId == null || userId.isEmpty) {
          setState(() => _errorText = 'Verification failed. Please try again.');
          return;
        }
        await _authService.completeDriverSignup(
          password: widget.signupPassword!,
          fullName: widget.fullName ?? '',
          phone: widget.phone ?? '',
          city: widget.city ?? '',
          vehicleType: widget.vehicleType!,
          userId: userId,
        );
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/waiting-approval',
          (_) => false,
        );
        return;
      }

      final response = widget.mode == AuthFlowMode.login
          ? await _authService.verifyLoginOtp(email: widget.email, token: token)
          : await _authService.verifySignupOtp(
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
          throw StateError(
            'Driver signup should complete before reaching the shared verification switch.',
          );

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
    final canResend =
        _hasValidSignupContext && _secondsRemaining <= 0 && !_isLoading;

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
            enabled: _hasValidSignupContext && !_isLoading,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            enableSuggestions: false,
            autocorrect: false,
            style: AppTextStyles.heading2,
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              hintText: 'Enter code',
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
            onPressed: (_isLoading || !_hasValidSignupContext)
                ? null
                : _verifyOtp,
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
