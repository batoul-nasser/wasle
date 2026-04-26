import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';
import 'otp_verification_screen.dart';

class CompanySignUpScreen extends StatefulWidget {
  const CompanySignUpScreen({super.key});

  @override
  State<CompanySignUpScreen> createState() => _CompanySignUpScreenState();
}

class _CompanySignUpScreenState extends State<CompanySignUpScreen> {
  static const Color blue = Color(0xFF2F80FF);

  final AuthService _authService = AuthService();

  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController adminNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  static const double _demoLat = 33.8938;
  static const double _demoLng = 35.5018;

  String? errorText;
  bool isLoading = false;
  bool isResolvingLocation = false;
  double? selectedLat;
  double? selectedLng;
  String? locationSourceLabel;

  Future<void> _useCurrentLocation() async {
    try {
      setState(() {
        isResolvingLocation = true;
        errorText = null;
      });

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on this device.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required to use current location.',
        );
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        selectedLat = position.latitude;
        selectedLng = position.longitude;
        locationSourceLabel = 'Current location selected';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = 'Unable to get current location: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isResolvingLocation = false;
        });
      }
    }
  }

  void _useDemoLocation() {
    setState(() {
      selectedLat = _demoLat;
      selectedLng = _demoLng;
      locationSourceLabel = 'Demo location selected';
      errorText = null;
    });
  }

  Future<void> _createCompanyAccount() async {
    final companyName = companyNameController.text.trim();
    final adminName = adminNameController.text.trim();
    final email = emailController.text.trim();
    final location = locationController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (companyName.isEmpty ||
        adminName.isEmpty ||
        email.isEmpty ||
        location.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        errorText = 'Please fill all fields';
      });
      return;
    }

    final emailValid = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
    if (!emailValid) {
      setState(() {
        errorText = 'Please enter a valid email address.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        errorText = 'Password must be at least 6 characters.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        errorText = 'Password and confirm password do not match.';
      });
      return;
    }

    if (selectedLat == null || selectedLng == null) {
      setState(() {
        errorText =
            'Please set the company location using current location or the demo preset.';
      });
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
            title: 'Verify Company Account',
            mode: AuthFlowMode.companySignup,
            fullName: adminName,
            companyName: companyName,
            location: location,
            companyLat: selectedLat,
            companyLng: selectedLng,
          ),
        ),
      );
    } catch (error, stackTrace) {
      AuthErrorMapper.log('otp_request_company_signup', error, stackTrace);
      setState(() {
        errorText = AuthErrorMapper.map(
          error,
          context: AuthErrorContext.otpRequest,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    companyNameController.dispose();
    adminNameController.dispose();
    emailController.dispose();
    locationController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: companyNameController,
              decoration: const InputDecoration(labelText: 'Company Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: adminNameController,
              decoration: const InputDecoration(labelText: 'Admin Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Company Address',
                hintText: 'Enter the company address',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading || isResolvingLocation
                        ? null
                        : _useCurrentLocation,
                    icon: const Icon(Icons.my_location_outlined),
                    label: Text(
                      isResolvingLocation
                          ? 'Locating...'
                          : 'Use Current Location',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : _useDemoLocation,
                    icon: const Icon(Icons.place_outlined),
                    label: const Text('Use Demo Location'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                locationSourceLabel ??
                    'Pick coordinates with current location or the demo preset. Lat/Lng are not typed manually.',
                style: TextStyle(
                  color: locationSourceLabel == null ? Colors.black54 : blue,
                  fontSize: 12,
                ),
              ),
            ),
            if (selectedLat != null && selectedLng != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Lat/Lng: ${selectedLat!.toStringAsFixed(6)}, ${selectedLng!.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading ? null : _createCompanyAccount,
                child: Text(
                  isLoading ? 'Loading...' : 'Create Company Account',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
