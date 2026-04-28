import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/pages/otp_verification_screen.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';

class PickupPointSignUpScreen extends StatefulWidget {
  const PickupPointSignUpScreen({super.key});

  @override
  State<PickupPointSignUpScreen> createState() => _PickupPointSignUpScreenState();
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
  final TextEditingController pickupPointNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController confirmAddressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController commissionValueController = TextEditingController();
  final TextEditingController maxOrdersPerDayController = TextEditingController();
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
  double? _selectedLatitude;
  double? _selectedLongitude;

  bool get _hasPickupLocation =>
      _selectedLatitude != null && _selectedLongitude != null;

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.of(context).push<_PickedPickupLocation>(
      MaterialPageRoute(
        builder: (_) => _PickupPointLocationPickerScreen(
          initialLat: _selectedLatitude,
          initialLng: _selectedLongitude,
          initialAddress: addressController.text.trim(),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedLatitude = result.lat;
      _selectedLongitude = result.lng;
      if (result.address.trim().isNotEmpty) {
        addressController.text = result.address.trim();
        if (confirmAddressController.text.trim().isEmpty) {
          confirmAddressController.text = result.address.trim();
        }
      }
      errorText = null;
    });
  }

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
    final latitude = _selectedLatitude;
    final longitude = _selectedLongitude;
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

    if (email.isEmpty) {
      setState(() => errorText = 'Email is still required.');
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      setState(() => errorText = 'Please enter a valid email address.');
      return;
    }

    if (address.isNotEmpty &&
        confirmAddress.isNotEmpty &&
        address != confirmAddress) {
      setState(() => errorText = 'Address and confirm address do not match.');
      return;
    }

    if (opensAt != null && closesAt != null) {
      final openMinutes = opensAt!.hour * 60 + opensAt!.minute;
      final closeMinutes = closesAt!.hour * 60 + closesAt!.minute;
      if (openMinutes >= closeMinutes) {
        setState(() {
          errorText = 'Opening time must be earlier than closing time.';
        });
        return;
      }
    }

    if (maxOrdersPerDay != null && maxOrdersPerDay <= 0) {
      setState(() => errorText = 'Max orders per day must be greater than 0.');
      return;
    }

    if (!_hasPickupLocation || latitude == null || longitude == null) {
      setState(() => errorText = 'Please pick pickup point location on the map.');
      return;
    }

    if (estimatedStorageSqm != null && estimatedStorageSqm <= 0) {
      setState(() => errorText = 'Estimated storage space must be greater than 0.');
      return;
    }

    if (estimatedCapacityUnits != null && estimatedCapacityUnits <= 0) {
      setState(() {
        errorText = 'Estimated parcel capacity must be greater than 0.';
      });
      return;
    }

    if (commissionType == 'custom' &&
        commissionValueController.text.trim().isNotEmpty) {
      if (commissionValue == null || commissionValue < 0 || commissionValue > 100) {
        setState(() => errorText = 'Commission value must be between 0 and 100.');
        return;
      }
    }

    if (password.isNotEmpty && password.length < 6) {
      setState(() => errorText = 'Password must be at least 6 characters.');
      return;
    }

    if (password.isNotEmpty &&
        confirmPassword.isNotEmpty &&
        password != confirmPassword) {
      setState(() => errorText = 'Password and confirm password do not match.');
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      final existingApplication = await _authService
          .getPickupPointApplicationByEmail(email);
      final existingStatus = existingApplication?['verification_status']
          ?.toString()
          .trim()
          .toLowerCase();

      if (existingStatus == 'rejected') {
        setState(() {
          errorText =
              'This pickup point application was already rejected. Please sign in with this account to view the rejected status.';
        });
        return;
      }

      if (existingStatus == 'pending') {
        setState(() {
          errorText =
              'This pickup point application is already pending review. Please sign in to view its status.';
        });
        return;
      }

      if (existingStatus == 'approved') {
        setState(() {
          errorText =
              'This pickup point account is already approved. Please sign in instead of signing up again.';
        });
        return;
      }

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
            password: password,
            fullName: ownerName,
            phone: phone,
            city: city,
            pickupPointName: pickupPointName,
            addressText: address,
            confirmAddressText: confirmAddress,
            area: area,
            branchLat: latitude,
            branchLng: longitude,
            maxOrdersPerDay: maxOrdersPerDay,
            workingDays: selectedWorkingDays.toList(),
            opensAt: opensAt == null ? null : _formatTimeOfDay(opensAt!),
            closesAt: closesAt == null ? null : _formatTimeOfDay(closesAt!),
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
                          style: AppTextStyles.heading2.copyWith(color: Colors.white),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.map_outlined),
                    title: const Text('Pickup Point Map Location'),
                    subtitle: Text(
                      _hasPickupLocation
                          ? 'Lat: ${_selectedLatitude!.toStringAsFixed(6)}, '
                              'Lng: ${_selectedLongitude!.toStringAsFixed(6)}'
                          : 'No location selected yet',
                    ),
                    trailing: TextButton(
                      onPressed: _pickLocationOnMap,
                      child: Text(_hasPickupLocation ? 'Change' : 'Pick'),
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
                    initialValue: storageTier,
                    decoration: const InputDecoration(
                      labelText: 'Storage Size',
                      prefixIcon: Icon(Icons.warehouse_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'small', child: Text('Small')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'large', child: Text('Large')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        storageTier = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: estimatedStorageSqmController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      DropdownMenuItem(value: 'custom', child: Text('Custom')),
                      DropdownMenuItem(value: 'plan', child: Text('Plan Based')),
                      DropdownMenuItem(value: 'negotiated', child: Text('Negotiated')),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Commission Value (%)',
                      prefixIcon: Icon(Icons.request_quote_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                    initialValue: paymentHandlingMethod,
                    decoration: const InputDecoration(
                      labelText: 'How will this pickup point send money to Wasle?',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'wish_money',
                        child: Text('Pickup Point Sends by Whish'),
                      ),
                      DropdownMenuItem(
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
                    label: Text(idImageName ?? 'Upload ID Verification Image'),
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

class _PickedPickupLocation {
  final double lat;
  final double lng;
  final String address;

  const _PickedPickupLocation({
    required this.lat,
    required this.lng,
    required this.address,
  });
}

class _PickupPointLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String initialAddress;

  const _PickupPointLocationPickerScreen({
    required this.initialLat,
    required this.initialLng,
    required this.initialAddress,
  });

  @override
  State<_PickupPointLocationPickerScreen> createState() =>
      _PickupPointLocationPickerScreenState();
}

class _PickupPointLocationPickerScreenState
    extends State<_PickupPointLocationPickerScreen> {
  late final TextEditingController _addressController;
  late gmaps.LatLng _selectedLatLng;
  final MapController _desktopMapController = MapController();
  gmaps.GoogleMapController? _mapController;
  double _desktopZoom = 16;

  bool get _useGoogleMapsPlugin =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  latlong.LatLng get _desktopLatLng =>
      latlong.LatLng(_selectedLatLng.latitude, _selectedLatLng.longitude);

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    _selectedLatLng = gmaps.LatLng(
      widget.initialLat ?? 33.8938,
      widget.initialLng ?? 35.5018,
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    final next = gmaps.LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() => _selectedLatLng = next);
    if (_useGoogleMapsPlugin) {
      await _mapController?.animateCamera(gmaps.CameraUpdate.newLatLngZoom(next, 16));
    } else {
      _desktopZoom = 16;
      _desktopMapController.move(_desktopLatLng, _desktopZoom);
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      _PickedPickupLocation(
        lat: _selectedLatLng.latitude,
        lng: _selectedLatLng.longitude,
        address: _addressController.text.trim(),
      ),
    );
  }

  Widget _buildMap() {
    if (_useGoogleMapsPlugin) {
      return gmaps.GoogleMap(
        initialCameraPosition: gmaps.CameraPosition(
          target: _selectedLatLng,
          zoom: 16,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: {
          gmaps.Marker(
            markerId: const gmaps.MarkerId('pickup_point_location'),
            position: _selectedLatLng,
          ),
        },
        onTap: (latLng) => setState(() => _selectedLatLng = latLng),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      );
    }

    return FlutterMap(
      mapController: _desktopMapController,
      options: MapOptions(
        initialCenter: _desktopLatLng,
        initialZoom: _desktopZoom,
        onTap: (_, point) {
          setState(() {
            _selectedLatLng = gmaps.LatLng(point.latitude, point.longitude);
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.wasle.app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              width: 46,
              height: 46,
              point: _desktopLatLng,
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.danger,
                size: 44,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Pickup Point Location')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'pp-my-location',
                        onPressed: _useCurrentLocation,
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: PrimaryButton(
              label: 'Use This Location',
              icon: Icons.check_circle_outline,
              onPressed: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}
