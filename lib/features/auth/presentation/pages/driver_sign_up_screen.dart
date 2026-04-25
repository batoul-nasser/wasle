// File: lib/features/auth/presentation/pages/driver_sign_up_screen.dart

import 'package:flutter/material.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';
import 'otp_verification_screen.dart';

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

  VehicleType? _selectedVehicle;
  String? errorText;
  bool isLoading = false;

  bool _containsDigitsOnly(String phone) => RegExp(r'^[0-9]+$').hasMatch(phone);

  bool _isValidPhoneLength(String phone) =>
      phone.length >= 7 && phone.length <= 15;

  Future<void> _createAccount() async {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final city = cityController.text.trim();
    final selectedVehicle = _selectedVehicle;

    if (fullName.isEmpty || email.isEmpty || phone.isEmpty || city.isEmpty) {
      setState(() => errorText = 'Please fill all fields');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => errorText = 'Please enter a valid email address.');
      return;
    }

    if (!_containsDigitsOnly(phone)) {
      setState(() => errorText = 'Phone number must contain digits only');
      return;
    }

    if (!_isValidPhoneLength(phone)) {
      setState(
        () => errorText = 'Phone number must be between 7 and 15 digits',
      );
      return;
    }

    if (selectedVehicle == null) {
      setState(() => errorText = 'Please select a vehicle type');
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
            vehicleType: selectedVehicle,
          ),
        ),
      );
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_request_driver_signup', error, stackTrace);
      setState(
        () => errorText = AuthErrorMapper.map(
          error,
          context: AuthErrorContext.otpRequest,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
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
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          // ── Hero header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JOIN AS DRIVER',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Create your driver account',
                  style: AppTextStyles.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'After signup, you will apply to a delivery company.',
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Personal info ──────────────────────────────────────────────
          TextField(
            controller: fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: cityController,
            decoration: const InputDecoration(
              labelText: 'City / Location',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Vehicle type selector ──────────────────────────────────────
          Text('Vehicle Type', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your vehicle determines your load capacity.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: VehicleType.values.map((v) {
              final isSelected = _selectedVehicle == v;
              final icon = _vehicleIcon(v);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: v != VehicleType.van ? AppSpacing.sm : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedVehicle = v;
                      errorText = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                        horizontal: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primarySoft
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 2 : 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            icon,
                            size: 28,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            v.displayName,
                            style: AppTextStyles.label.copyWith(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '≤ ${v.maxWeightKg.toInt()}kg',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // ── Capacity preview ───────────────────────────────────────────
          const SizedBox(height: AppSpacing.md),
          if (_selectedVehicle == null)
            InfoCard(
              title: 'Vehicle Required',
              subtitle: 'Choose a vehicle type before creating your account.',
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ),
              child: const Text(
                'Capacity will appear after vehicle selection.',
              ),
            )
          else
            InfoCard(
              title: 'Your Capacity (${_selectedVehicle!.displayName})',
              subtitle: 'Auto-assigned by platform',
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              child: Row(
                children: [
                  _CapStat(
                    label: 'Max Weight',
                    value: '${_selectedVehicle!.maxWeightKg.toInt()} kg',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _CapStat(
                    label: 'Max Items',
                    value: '${_selectedVehicle!.maxItemCount}',
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.xl),

          if (errorText != null) ...[
            Text(
              errorText!,
              style: AppTextStyles.body.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          PrimaryButton(
            label: 'Create Account',
            icon: Icons.check_circle_outline,
            isLoading: isLoading,
            onPressed: isLoading ? null : _createAccount,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  IconData _vehicleIcon(VehicleType v) {
    switch (v) {
      case VehicleType.motorcycle:
        return Icons.two_wheeler_outlined;
      case VehicleType.car:
        return Icons.directions_car_outlined;
      case VehicleType.van:
        return Icons.local_shipping_outlined;
    }
  }
}

class _CapStat extends StatelessWidget {
  final String label;
  final String value;

  const _CapStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.title),
        ],
      ),
    );
  }
}
