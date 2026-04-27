import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/pages/otp_verification_screen.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';

class PickupPointSignUpScreen extends StatefulWidget {
  const PickupPointSignUpScreen({super.key});

  @override
  State<PickupPointSignUpScreen> createState() =>
      _PickupPointSignUpScreenState();
}

class _PickupPointSignUpScreenState extends State<PickupPointSignUpScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  static const List<String> _weekDays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static final RegExp _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController pickupPointNameController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController confirmAddressController =
      TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController commissionValueController =
      TextEditingController();
  final TextEditingController maxOrdersPerDayController =
      TextEditingController();
  final TextEditingController estimatedStorageSqmController =
      TextEditingController();
  final TextEditingController estimatedCapacityUnitsController =
      TextEditingController();

  TimeOfDay? opensAt;
  TimeOfDay? closesAt;

  String preferredPaymentMethod = 'wish_money';
  String paymentHandlingMethod = 'wish_money';
  String commissionType = 'custom';
  String storageTier = 'medium';
  bool hasShelves = false;

  final Set<String> selectedWorkingDays = <String>{
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  };

  Uint8List? shopImageBytes;
  Uint8List? idImageBytes;
  Uint8List? storageAreaImageBytes;
  Uint8List? shelvesImageBytes;

  String? shopImageName;
  String? idImageName;
  String? storageAreaImageName;
  String? shelvesImageName;

  bool isLoading = false;
  String? errorText;

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Widget _buildImagePreview(Uint8List? bytes) {
    if (bytes == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          bytes,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Future<void> _pickShopImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      shopImageBytes = bytes;
      shopImageName = file.name;
    });
  }

  Future<void> _pickIdImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      idImageBytes = bytes;
      idImageName = file.name;
    });
  }

  Future<void> _pickStorageAreaImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      storageAreaImageBytes = bytes;
      storageAreaImageName = file.name;
    });
  }

  Future<void> _pickShelvesImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      shelvesImageBytes = bytes;
      shelvesImageName = file.name;
    });
  }

  Future<void> _pickOpeningTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: opensAt ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (result == null) return;

    setState(() {
      opensAt = result;
    });
  }

  Future<void> _pickClosingTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: closesAt ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (result == null) return;

    setState(() {
      closesAt = result;
    });
  }

  Future<void> _createPickupPointAccount() async {
    final ownerName = ownerNameController.text.trim();
    final pickupPointName = pickupPointNameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final address = addressController.text.trim();
    final confirmAddress = confirmAddressController.text.trim();
    final city = cityController.text.trim();
    final area = areaController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    final maxOrdersPerDay =
        int.tryParse(maxOrdersPerDayController.text.trim());

    final estimatedStorageSqm =
        double.tryParse(estimatedStorageSqmController.text.trim());
    final estimatedCapacityUnits =
        int.tryParse(estimatedCapacityUnitsController.text.trim());
    final commissionValue =
        double.tryParse(commissionValueController.text.trim());

    if (ownerName.isEmpty ||
        pickupPointName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        address.isEmpty ||
        confirmAddress.isEmpty ||
        city.isEmpty ||
        area.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => errorText = 'Please fill all required fields.');
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      setState(() => errorText = 'Please enter a valid email address.');
      return;
    }

    if (address != confirmAddress) {
      setState(() => errorText = 'Address and confirm address do not match.');
      return;
    }

    if (opensAt == null || closesAt == null) {
      setState(() => errorText = 'Please select working hours.');
      return;
    }

    if (selectedWorkingDays.isEmpty) {
      setState(() => errorText = 'Please select at least one working day.');
      return;
    }

    final openMinutes = opensAt!.hour * 60 + opensAt!.minute;
    final closeMinutes = closesAt!.hour * 60 + closesAt!.minute;
    if (openMinutes >= closeMinutes) {
      setState(() {
        errorText = 'Opening time must be earlier than closing time.';
      });
      return;
    }

    if (maxOrdersPerDay == null || maxOrdersPerDay <= 0) {
      setState(() => errorText = 'Max orders per day must be greater than 0.');
      return;
    }

    if (estimatedStorageSqm != null && estimatedStorageSqm <= 0) {
      setState(() {
        errorText = 'Estimated storage space must be greater than 0.';
      });
      return;
    }

    if (estimatedCapacityUnits != null && estimatedCapacityUnits <= 0) {
      setState(() {
        errorText = 'Estimated parcel capacity must be greater than 0.';
      });
      return;
    }

    if (commissionType == 'custom') {
      if (commissionValue == null ||
          commissionValue < 0 ||
          commissionValue > 100) {
        setState(() => errorText = 'Commission value must be between 0 and 100.');
        return;
      }
    }

    if (shopImageBytes == null ||
        idImageBytes == null ||
        storageAreaImageBytes == null ||
        shelvesImageBytes == null) {
      setState(() {
        errorText =
            'Please upload shop, ID, storage area, and shelves images.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() => errorText = 'Password must be at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      setState(
        () => errorText = 'Password and confirm password do not match.',
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      await _authService.sendOtp(
        email: email,
        shouldCreateUser: true,
        data: {'role': 'pickup_point_applicant', 'full_name': ownerName},
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            title: 'Verify Pickup Point Account',
            mode: AuthFlowMode.pickupPointSignup,
            fullName: ownerName,
            phone: phone,
            city: city,
            pickupPointName: pickupPointName,
            addressText: address,
            confirmAddressText: confirmAddress,
            area: area,
            maxOrdersPerDay: maxOrdersPerDay,
            workingDays: selectedWorkingDays.toList(),
            opensAt: _formatTimeOfDay(opensAt!),
            closesAt: _formatTimeOfDay(closesAt!),
            preferredPaymentMethod: preferredPaymentMethod,
            paymentHandlingMethod: paymentHandlingMethod,
            commissionType: commissionType,
            commissionValue: commissionValue,
            storageTier: storageTier,
            estimatedStorageSqm: estimatedStorageSqm,
            hasShelves: hasShelves,
            estimatedCapacityUnits: estimatedCapacityUnits,
            shopImageBytes: shopImageBytes,
            idImageBytes: idImageBytes,
            storageAreaImageBytes: storageAreaImageBytes,
            shelvesImageBytes: shelvesImageBytes,
            shopImageFileName: shopImageName,
            idImageFileName: idImageName,
            storageAreaImageFileName: storageAreaImageName,
            shelvesImageFileName: shelvesImageName,
          ),
        ),
      );
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_request_pickup_point_signup', error, stackTrace);
      setState(() {
        errorText = AuthErrorMapper.map(
          error,
          context: AuthErrorContext.otpRequest,
        );
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    ownerNameController.dispose();
    pickupPointNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    confirmAddressController.dispose();
    cityController.dispose();
    areaController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    commissionValueController.dispose();
    maxOrdersPerDayController.dispose();
    estimatedStorageSqmController.dispose();
    estimatedCapacityUnitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final openText =
        opensAt == null ? 'Select opening time' : opensAt!.format(context);
    final closeText =
        closesAt == null ? 'Select closing time' : closesAt!.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Point Sign Up'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.store_mall_directory_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create your pickup point application',
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Complete your location, storage, payment, and verification details.',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            InfoCard(
              child: Column(
                children: [
                  TextField(
                    controller: ownerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Owner Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: pickupPointNameController,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Point Name',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
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
                    controller: addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: confirmAddressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Address',
                      prefixIcon: Icon(Icons.location_searching_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: areaController,
                    decoration: const InputDecoration(
                      labelText: 'Area',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: maxOrdersPerDayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Orders Per Day',
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Working Days',
                      style: AppTextStyles.title,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _weekDays.map((day) {
                      final isSelected = selectedWorkingDays.contains(day);
                      return FilterChip(
                        label: Text(day),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedWorkingDays.add(day);
                            } else {
                              selectedWorkingDays.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: paymentHandlingMethod,
                    decoration: const InputDecoration(
                      labelText:
                          'How will this pickup point send money to Wasle?',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'wish_money',
                        child: Text('Pickup Point Sends by Whish'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'agent_collection',
                        child: Text('Wasle Agent Collects from Pickup Point'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        paymentHandlingMethod = value;
                        preferredPaymentMethod = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: estimatedStorageSqmController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Estimated Storage Space (sqm)',
                      prefixIcon: Icon(Icons.square_foot_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: estimatedCapacityUnitsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Parcel Capacity',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Storage Includes Shelves'),
                    value: hasShelves,
                    onChanged: (value) {
                      setState(() {
                        hasShelves = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: commissionType,
                    decoration: const InputDecoration(
                      labelText: 'Commission Type',
                      prefixIcon: Icon(Icons.percent_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Custom'),
                      ),
                      DropdownMenuItem(
                        value: 'plan',
                        child: Text('Plan Based'),
                      ),
                      DropdownMenuItem(
                        value: 'negotiated',
                        child: Text('Negotiated'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        commissionType = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: commissionValueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Commission Value (%)',
                      prefixIcon: Icon(Icons.request_quote_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Opening Time'),
                    subtitle: Text(openText),
                    trailing: TextButton(
                      onPressed: _pickOpeningTime,
                      child: const Text('Select'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Closing Time'),
                    subtitle: Text(closeText),
                    trailing: TextButton(
                      onPressed: _pickClosingTime,
                      child: const Text('Select'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _pickShopImage,
                    icon: const Icon(Icons.store_mall_directory_outlined),
                    label: Text(shopImageName ?? 'Upload Shop Image'),
                  ),
                  _buildImagePreview(shopImageBytes),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _pickIdImage,
                    icon: const Icon(Icons.badge_outlined),
                    label: Text(
                      idImageName ?? 'Upload ID Verification Image',
                    ),
                  ),
                  _buildImagePreview(idImageBytes),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _pickStorageAreaImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      storageAreaImageName ?? 'Upload Storage Area Image',
                    ),
                  ),
                  _buildImagePreview(storageAreaImageBytes),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _pickShelvesImage,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(shelvesImageName ?? 'Upload Shelves Image'),
                  ),
                  _buildImagePreview(shelvesImageBytes),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_clock_outlined),
                    ),
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
              label: 'Submit Pickup Point Application',
              icon: Icons.sms_outlined,
              isLoading: isLoading,
              onPressed: _createPickupPointAccount,
            ),
          ],
        ),
      ),
    );
  }
}
