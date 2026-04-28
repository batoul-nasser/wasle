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
  final String? companyId;
  final String? vehicleType;
  final String? password;
  final String? companyName;
  final String? companyPhone;
  final String? location;
  final String? exactAddress;
  final String? companyCity;
  final String? companyArea;
  final double? companyLat;
  final double? companyLng;
  final String? businessName;
  final String? branchName;
  final String? addressText;
  final double? branchLat;
  final double? branchLng;
  final String? pickupPointName;
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
    this.companyId,
    this.vehicleType,
    this.password,
    this.companyName,
    this.companyPhone,
    this.location,
    this.exactAddress,
    this.companyCity,
    this.companyArea,
    this.companyLat,
    this.companyLng,
    this.businessName,
    this.branchName,
    this.addressText,
    this.branchLat,
    this.branchLng,
    this.pickupPointName,
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
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();
  int get _otpLength => 6;


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

  double _requiredDouble(double? value, String fieldName) {
    if (value == null) {
      throw Exception('$fieldName is required');
    }
    return value;
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
    if (ext.isEmpty) return 'jpg';
    return ext;
  }

  String _safeEmail() {
    return widget.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  String? _validateOtpInput(String otp) {
    if (otp.isEmpty) {
      return 'Please enter the verification code.';
    }

    if (!RegExp(r'^\d+$').hasMatch(otp)) {
      return 'OTP code must contain numbers only.';
    }

    if (otp.length != _otpLength) {
      return 'Please enter the $_otpLength-digit verification code.';
    }

    return null;
  }

  void _goTo(String routeName) {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    final otp = _otpController.text.trim();
    final normalizedEmail = widget.email.trim().toLowerCase();
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
        email: normalizedEmail,
        token: otp,
        mode: widget.mode,
      );
      final userId = response.user?.id ?? _authService.currentUser?.id;

      switch (widget.mode) {
        case AuthFlowMode.driverSignup:
          if (userId == null) {
            throw Exception('User session not found after OTP verification');
          }
          await _authService.setCurrentUserPassword(
            _required(widget.password, 'Password'),
          );
          await _authService.createDriverProfile(
            userId: userId,
            fullName: _required(widget.fullName, 'Full name'),
            phone: _required(widget.phone, 'Phone'),
            city: _required(widget.city, 'City'),
            companyId: _required(widget.companyId, 'Delivery company'),
            vehicleType: _required(widget.vehicleType, 'Vehicle type'),
          );
          _goTo('/waiting-approval');
          return;

        case AuthFlowMode.companySignup:
          if (userId == null) {
            throw Exception('User session not found after OTP verification');
          }
          await _authService.setCurrentUserPassword(
            _required(widget.password, 'Password'),
          );
          await _authService.createCompanyProfile(
            userId: userId,
            adminName: _required(widget.fullName, 'Admin name'),
            companyName: _required(widget.companyName, 'Company name'),
            phone: _required(widget.companyPhone ?? widget.phone, 'Phone'),
            email: normalizedEmail,
            exactAddress: _required(
              widget.exactAddress ?? widget.location,
              'Exact address',
            ),
            city: _required(widget.companyCity ?? widget.city, 'City'),
            area: _required(widget.companyArea ?? widget.area, 'Area'),
            latitude: _requiredDouble(
              widget.companyLat ?? widget.branchLat,
              'Latitude',
            ),
            longitude: _requiredDouble(
              widget.companyLng ?? widget.branchLng,
              'Longitude',
            ),
          );
          _goTo('/company-dashboard');
          return;

        case AuthFlowMode.customerSignup:
          if (userId == null) {
            throw Exception('User session not found after OTP verification');
          }
          await _authService.setCurrentUserPassword(
            _required(widget.password, 'Password'),
          );
          await _authService.createCustomerProfile(
            userId: userId,
            fullName: _required(widget.fullName, 'Full name'),
            phone: _required(widget.phone, 'Phone'),
          );
          _goTo('/customer-dashboard');
          return;

        case AuthFlowMode.merchantSignup:
          if (userId == null) {
            throw Exception('User session not found after OTP verification');
          }
          await _authService.setCurrentUserPassword(
            _required(widget.password, 'Password'),
          );
          await _authService.createMerchantProfile(
            userId: userId,
            fullName: _required(widget.fullName, 'Full name'),
            phone: _required(widget.phone, 'Phone'),
            businessName: _required(widget.businessName, 'Business name'),
            branchName: _required(widget.branchName, 'Branch name'),
            addressText: _required(widget.addressText, 'Branch address'),
            branchLat: _requiredDouble(widget.branchLat, 'Branch latitude'),
            branchLng: _requiredDouble(widget.branchLng, 'Branch longitude'),
          );
          _goTo('/merchant-dashboard');
          return;

        case AuthFlowMode.pickupPointSignup:
          if (userId == null) {
            throw Exception('User session not found after OTP verification');
          }
          await _authService.setCurrentUserPassword(
            _required(widget.password, 'Password'),
          );
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
            email: normalizedEmail,
            pickupPointName: _required(
              widget.pickupPointName,
              'Pickup point name',
            ),
            addressText: _required(widget.addressText, 'Address'),
            confirmAddressText: _required(
              widget.confirmAddressText,
              'Confirm address',
            ),
            lat: widget.branchLat,
            lng: widget.branchLng,
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
          if (userId == null) {
            throw Exception('User session not found after OTP verification');
          }
          final route = await _authService.resolveInitialRoute();
          if (route == '/welcome') {
            await _authService.signOut();
            throw Exception(
              'No account setup found for this user. Please sign up first.',
            );
          }
          _goTo(route);
          return;
      }
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_verify', error, stackTrace);
      final mappedError = AuthErrorMapper.map(
        error,
        context: AuthErrorContext.otpVerification,
      );
      setState(() {
        _errorText = mappedError;
        if (mappedError.toLowerCase().contains('expired')) {
          _secondsRemaining = 0;
          _timer?.cancel();
        }
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

      if (widget.mode == AuthFlowMode.login) {
        await _authService.resendLoginOtp(
          email: widget.email.trim().toLowerCase(),
        );
      } else {
        await _authService.resendSignupOtp(
          email: widget.email.trim().toLowerCase(),
        );
      }

      _startTimer();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code sent successfully.')));
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
      appBar: AppBar(title: Text(widget.title)),
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
                      Text('Expires in ', style: AppTextStyles.bodyMuted),
                      Text(
                        timeText,
                        style: AppTextStyles.title.copyWith(
                          color: AppColors.primary,
                        ),
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
              onPressed: _isLoading ? null : _verifyOtp,
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
