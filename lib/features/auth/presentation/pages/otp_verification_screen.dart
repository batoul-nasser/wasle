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
  final double? companyLat;
  final double? companyLng;
  final String? businessName;
  final String? pickupPointName;
  final String? addressText;
  final String? confirmAddressText;
  final String? area;
  final int? maxOrdersPerDay;
  final List<String>? workingDays;
  final String? opensAt;
  final String? closesAt;
  final double? commissionPercentage;
  final String? preferredPaymentMethod;
  final String? paymentHandlingMethod;
  final String? commissionType;
  final double? commissionValue;
  final String? commissionPlan;
  final String? storageTier;
  final double? estimatedStorageSqm;
  final bool? hasShelves;
  final int? estimatedCapacityUnits;
  final Uint8List? shopImageBytes;
  final Uint8List? idImageBytes;
  final Uint8List? storageAreaImageBytes;
  final Uint8List? shelvesImageBytes;
  final String? shopImageFileName;
  final String? idImageFileName;
  final String? storageAreaImageFileName;
  final String? shelvesImageFileName;

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
    this.companyLat,
    this.companyLng,
    this.businessName,
    this.pickupPointName,
    this.addressText,
    this.confirmAddressText,
    this.area,
    this.maxOrdersPerDay,
    this.workingDays,
    this.opensAt,
    this.closesAt,
    this.commissionPercentage,
    this.preferredPaymentMethod,
    this.paymentHandlingMethod,
    this.commissionType,
    this.commissionValue,
    this.commissionPlan,
    this.storageTier,
    this.estimatedStorageSqm,
    this.hasShelves,
    this.estimatedCapacityUnits,
    this.shopImageBytes,
    this.idImageBytes,
    this.storageAreaImageBytes,
    this.shelvesImageBytes,
    this.shopImageFileName,
    this.idImageFileName,
    this.storageAreaImageFileName,
    this.shelvesImageFileName,
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
            widget.location!.trim().isNotEmpty &&
            widget.companyLat != null &&
            widget.companyLng != null;
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
      case AuthFlowMode.pickupPointSignup:
        return widget.fullName != null &&
            widget.fullName!.trim().isNotEmpty &&
            widget.phone != null &&
            widget.phone!.trim().isNotEmpty &&
            widget.city != null &&
            widget.city!.trim().isNotEmpty &&
            widget.pickupPointName != null &&
            widget.pickupPointName!.trim().isNotEmpty &&
            widget.addressText != null &&
            widget.addressText!.trim().isNotEmpty &&
            widget.confirmAddressText != null &&
            widget.confirmAddressText!.trim().isNotEmpty &&
            widget.area != null &&
            widget.area!.trim().isNotEmpty &&
            widget.opensAt != null &&
            widget.opensAt!.trim().isNotEmpty &&
            widget.closesAt != null &&
            widget.closesAt!.trim().isNotEmpty &&
            widget.preferredPaymentMethod != null &&
            widget.preferredPaymentMethod!.trim().isNotEmpty &&
            widget.shopImageBytes != null &&
            widget.idImageBytes != null &&
            widget.storageAreaImageBytes != null &&
            widget.shelvesImageBytes != null;
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
      case AuthFlowMode.pickupPointSignup:
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

  String _required(String? value, String fieldName) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      throw Exception('$fieldName is required');
    }
    return text;
  }

  Uint8List _requiredBytes(Uint8List? value, String fieldName) {
    if (value == null || value.isEmpty) {
      throw Exception('$fieldName is required');
    }
    return value;
  }

  String _fileExtension(String? fileName) {
    if (fileName == null || !fileName.contains('.')) {
      return 'jpg';
    }
    final ext = fileName.split('.').last.trim().toLowerCase();
    return ext.isEmpty ? 'jpg' : ext;
  }

  String _safeEmail() {
    return widget.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  void _goTo(String routeName) {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
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
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_resend', error, stackTrace);
      setState(
        () => _errorText = AuthErrorMapper.map(
          error,
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

        _goTo('/waiting-approval');
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
            addressText: widget.location ?? '',
            lat: widget.companyLat!,
            lng: widget.companyLng!,
          );
          _goTo('/company-dashboard');
          return;
        case AuthFlowMode.customerSignup:
          await _authService.createCustomerProfile(
            userId: userId,
            fullName: widget.fullName ?? '',
            phone: widget.phone ?? '',
          );
          _goTo('/customer-dashboard');
          return;
        case AuthFlowMode.merchantSignup:
          await _authService.createMerchantProfile(
            userId: userId,
            fullName: widget.fullName ?? '',
            phone: widget.phone ?? '',
            businessName: widget.businessName ?? '',
          );
          _goTo('/merchant-dashboard');
          return;
        case AuthFlowMode.pickupPointSignup:
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final safeEmail = _safeEmail();

          final shopFileName =
              '${safeEmail}_shop_$timestamp.${_fileExtension(widget.shopImageFileName)}';
          final idFileName =
              '${safeEmail}_id_$timestamp.${_fileExtension(widget.idImageFileName)}';
          final storageAreaFileName =
              '${safeEmail}_storage_$timestamp.${_fileExtension(widget.storageAreaImageFileName)}';
          final shelvesFileName =
              '${safeEmail}_shelves_$timestamp.${_fileExtension(widget.shelvesImageFileName)}';

          final shopUrl = await _authService.uploadPickupPointShopImage(
            fileName: shopFileName,
            bytes: _requiredBytes(widget.shopImageBytes, 'Shop image'),
          );
          final idUrl = await _authService.uploadPickupPointIdImage(
            fileName: idFileName,
            bytes: _requiredBytes(widget.idImageBytes, 'ID image'),
          );
          final storageAreaUrl = await _authService
              .uploadPickupPointStorageAreaImage(
                fileName: storageAreaFileName,
                bytes: _requiredBytes(
                  widget.storageAreaImageBytes,
                  'Storage area image',
                ),
              );
          final shelvesUrl = await _authService.uploadPickupPointShelvesImage(
            fileName: shelvesFileName,
            bytes: _requiredBytes(widget.shelvesImageBytes, 'Shelves image'),
          );

          if (shopUrl == null ||
              idUrl == null ||
              storageAreaUrl == null ||
              shelvesUrl == null) {
            throw Exception('Failed to upload pickup point images');
          }

          await _authService.createPickupPointApplication(
            userId: userId,
            ownerName: _required(widget.fullName, 'Owner name'),
            phone: _required(widget.phone, 'Phone'),
            email: widget.email,
            pickupPointName: _required(
              widget.pickupPointName,
              'Pickup point name',
            ),
            addressText: _required(widget.addressText, 'Address'),
            confirmAddressText: _required(
              widget.confirmAddressText,
              'Confirm address',
            ),
            city: _required(widget.city, 'City'),
            area: _required(widget.area, 'Area'),
            maxOrdersPerDay: widget.maxOrdersPerDay,
            workingDays: widget.workingDays,
            opensAt: _required(widget.opensAt, 'Opening time'),
            closesAt: _required(widget.closesAt, 'Closing time'),
            commissionType: widget.commissionType ?? 'custom',
            commissionValue: widget.commissionValue,
            commissionPlan: widget.commissionPlan,
            preferredPaymentMethod: _required(
              widget.preferredPaymentMethod,
              'Preferred payment method',
            ),
            paymentHandlingMethod: widget.paymentHandlingMethod,
            storageTier: widget.storageTier,
            estimatedStorageSqm: widget.estimatedStorageSqm,
            hasShelves: widget.hasShelves ?? false,
            estimatedCapacityUnits: widget.estimatedCapacityUnits,
            shopImageUrl: shopUrl,
            idImageUrl: idUrl,
            storageAreaImageUrl: storageAreaUrl,
            shelvesImageUrl: shelvesUrl,
          );
          _goTo('/pickup-application-pending');
          return;
        case AuthFlowMode.login:
          final route = await _authService.resolveInitialRoute();
          _goTo(route);
          return;
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
            style: AppTextStyles.display.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              labelText: 'Verification Code',
              counterText: '',
              labelStyle: AppTextStyles.label.copyWith(
                color: AppColors.primary,
              ),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
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
