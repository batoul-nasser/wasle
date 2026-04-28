import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/pages/otp_verification_screen.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';

class MerchantSignUpScreen extends StatefulWidget {
  const MerchantSignUpScreen({super.key});

  @override
  State<MerchantSignUpScreen> createState() => _MerchantSignUpScreenState();
}

class _MerchantSignUpScreenState extends State<MerchantSignUpScreen> {
  final AuthService _authService = AuthService();
  static final RegExp _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final TextEditingController branchNameController =
      TextEditingController(text: 'Main Branch');
  final TextEditingController addressController = TextEditingController();

  bool isLoading = false;
  String? errorText;

  double? _selectedLat;
  double? _selectedLng;

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.of(context).push<_PickedMerchantLocation>(
      MaterialPageRoute(
        builder: (_) => _MerchantLocationPickerScreen(
          initialLat: _selectedLat,
          initialLng: _selectedLng,
          initialAddress: addressController.text.trim(),
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedLat = result.lat;
      _selectedLng = result.lng;
      if (result.address.trim().isNotEmpty) {
        addressController.text = result.address.trim();
      }
    });
  }

  Future<void> _sendOtp() async {
    final fullName = fullNameController.text.trim();
    final businessName = businessNameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    final branchName = branchNameController.text.trim();
    final addressText = addressController.text.trim();

    if (fullName.isEmpty ||
        businessName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        branchName.isEmpty ||
        addressText.isEmpty) {
      setState(() => errorText = 'Please fill all fields');
      return;
    }

    if (_selectedLat == null || _selectedLng == null) {
      setState(() => errorText = 'Please pick the merchant location on the map.');
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      setState(() => errorText = 'Please enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      setState(() => errorText = 'Password must be at least 6 characters.');
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

      await _authService.sendOtp(
        email: email,
        shouldCreateUser: true,
        data: {'role': 'merchant', 'full_name': fullName},
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            title: 'Verify Merchant Account',
            mode: AuthFlowMode.merchantSignup,
            password: password,
            fullName: fullName,
            phone: phone,
            businessName: businessName,
            branchName: branchName,
            addressText: addressText,
            branchLat: _selectedLat,
            branchLng: _selectedLng,
          ),
        ),
      );
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_request_merchant_signup', error, stackTrace);
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
    businessNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    branchNameController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPickedLocation = _selectedLat != null && _selectedLng != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ListView(
          children: [
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: businessNameController,
              decoration: const InputDecoration(labelText: 'Business Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: branchNameController,
              decoration: const InputDecoration(labelText: 'Branch Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Branch Address'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: isLoading ? null : _pickLocationOnMap,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                hasPickedLocation
                    ? 'Change Branch Location on Map'
                    : 'Pick Branch Location on Map',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (hasPickedLocation)
              Text(
                'Selected location: ${_selectedLat!.toStringAsFixed(6)}, ${_selectedLng!.toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.green),
              )
            else
              const Text(
                'No branch location selected yet.',
                style: TextStyle(color: Colors.orange),
              ),
            const SizedBox(height: AppSpacing.lg),
            if (errorText != null)
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Send OTP',
              onPressed: isLoading ? null : _sendOtp,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedMerchantLocation {
  final double lat;
  final double lng;
  final String address;

  const _PickedMerchantLocation({
    required this.lat,
    required this.lng,
    required this.address,
  });
}

class _MerchantLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String initialAddress;

  const _MerchantLocationPickerScreen({
    required this.initialLat,
    required this.initialLng,
    required this.initialAddress,
  });

  @override
  State<_MerchantLocationPickerScreen> createState() =>
      _MerchantLocationPickerScreenState();
}

class _MerchantLocationPickerScreenState
    extends State<_MerchantLocationPickerScreen> {
  late final TextEditingController _addressController;
  late LatLng _selectedLatLng;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    _selectedLatLng = LatLng(
      widget.initialLat ?? 33.8938,
      widget.initialLng ?? 35.5018,
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _zoomIn() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.zoomOut());
  }

  void _confirm() {
    Navigator.of(context).pop(
      _PickedMerchantLocation(
        lat: _selectedLatLng.latitude,
        lng: _selectedLatLng.longitude,
        address: _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Branch Location'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLatLng,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('merchant_branch'),
                      position: _selectedLatLng,
                    ),
                  },
                  onTap: (latLng) {
                    setState(() {
                      _selectedLatLng = latLng;
                    });
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  mapToolbarEnabled: true,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _MapZoomButton(
                        icon: Icons.add,
                        onTap: _zoomIn,
                      ),
                      const SizedBox(height: 8),
                      _MapZoomButton(
                        icon: Icons.remove,
                        onTap: _zoomOut,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Selected: ${_selectedLatLng.latitude.toStringAsFixed(6)}, ${_selectedLatLng.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: 'Use This Location',
                  onPressed: _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapZoomButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon),
        ),
      ),
    );
  }
}