import 'package:flutter/material.dart';
import 'package:wasle/core/domain/delivery_constraints.dart';
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
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? errorText;
  bool isLoading = false;
  bool isLoadingCompanies = true;
  List<Map<String, dynamic>> deliveryCompanies = [];
  String? selectedCompanyId;
  String selectedVehicleType = 'motorcycle';

  @override
  void initState() {
    super.initState();
    _loadDeliveryCompanies();
  }

  Future<void> _loadDeliveryCompanies() async {
    try {
      final companies = await _authService.getDeliveryCompanies();
      if (!mounted) return;
      setState(() {
        deliveryCompanies = companies;
        selectedCompanyId = companies.length == 1
            ? companies.first['id']?.toString()
            : null;
        isLoadingCompanies = false;
        errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoadingCompanies = false;
        errorText =
            'Unable to load delivery companies. Please try again in a moment.';
      });
    }
  }

  bool _containsDigitsOnly(String phone) {
    return RegExp(r'^[0-9]+$').hasMatch(phone);
  }

  bool _isValidPhoneLength(String phone) {
    return phone.length >= 7 && phone.length <= 15;
  }

  bool _isStrongPassword(String password) {
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    return password.length >= 8 &&
        hasLower &&
        hasUpper &&
        hasDigit &&
        hasSpecial;
  }

  Future<void> _createAccount() async {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final city = cityController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (fullName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        city.isEmpty ||
        selectedCompanyId == null ||
        selectedVehicleType.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => errorText = 'Please fill all fields');
      return;
    }

    final emailValid = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
    if (!emailValid) {
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

    if (!_isStrongPassword(password)) {
      setState(
        () => errorText =
            'Password must be 8+ chars and include uppercase, lowercase, number, and special character.',
      );
      return;
    }

    if (password != confirmPassword) {
      setState(() => errorText = 'Password and confirm password do not match.');
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
            companyId: selectedCompanyId,
            vehicleType: selectedVehicleType,
            password: password,
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
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cityController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _refreshDeliveryCompanies() async {
    setState(() {
      isLoadingCompanies = true;
      errorText = null;
    });
    await _loadDeliveryCompanies();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      decoration: _inputDecoration(label: label, icon: icon),
    );
  }

  String _companyLabel(Map<String, dynamic> company) {
    final name = company['name']?.toString().trim();
    final city = company['city']?.toString().trim();
    final area = company['area']?.toString().trim();
    final location = [
      if (city != null && city.isNotEmpty) city,
      if (area != null && area.isNotEmpty) area,
    ].join(' / ');

    if (name == null || name.isEmpty) return 'Delivery company';
    return location.isEmpty ? name : '$name - $location';
  }

  Widget _capacityPreview(VehicleCapacityProfile capacity) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated capacity',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${capacity.weightKg.toStringAsFixed(0)} kg, '
                  '${capacity.volumeCm3.toStringAsFixed(0)} cm3, '
                  '${capacity.itemCount} items',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyLoadState() {
    if (isLoadingCompanies || deliveryCompanies.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          const Expanded(
            child: Text(
              'No delivery companies are available right now.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(
            onPressed: _refreshDeliveryCompanies,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() {
    if (errorText == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              errorText!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capacity = DeliveryConstraintDefaults.capacityForVehicleType(
      selectedVehicleType,
    );
    final companyHint = isLoadingCompanies
        ? 'Loading delivery companies...'
        : deliveryCompanies.isEmpty
        ? 'No delivery companies available'
        : 'Select delivery company';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Driver Sign Up'),
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create your driver account',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Choose your company and vehicle so your approval request is ready for dispatch work.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle('Personal information'),
                _buildTextField(
                  controller: fullNameController,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: emailController,
                  label: 'Email',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: phoneController,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: cityController,
                  label: 'City / Location',
                  icon: Icons.location_city_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle('Company and vehicle'),
                DropdownButtonFormField<String>(
                  initialValue: selectedCompanyId,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Delivery Company',
                    icon: Icons.apartment_rounded,
                  ),
                  hint: Text(companyHint),
                  items: deliveryCompanies
                      .where(
                        (company) =>
                            (company['id']?.toString().trim() ?? '').isNotEmpty,
                      )
                      .map((company) {
                        final id = company['id']!.toString();
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            _companyLabel(company),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      })
                      .toList(),
                  onChanged: isLoadingCompanies || deliveryCompanies.isEmpty
                      ? null
                      : (value) => setState(() => selectedCompanyId = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                _companyLoadState(),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: selectedVehicleType,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Vehicle Type',
                    icon: Icons.two_wheeler_rounded,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'motorcycle',
                      child: Text('Motorcycle'),
                    ),
                    DropdownMenuItem(value: 'car', child: Text('Car')),
                    DropdownMenuItem(value: 'van', child: Text('Van')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => selectedVehicleType = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _capacityPreview(capacity),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle('Security'),
                _buildTextField(
                  controller: passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: confirmPasswordController,
                  label: 'Confirm Password',
                  icon: Icons.lock_reset_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                _errorBox(),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Create Account',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading || isLoadingCompanies
                      ? null
                      : _createAccount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
