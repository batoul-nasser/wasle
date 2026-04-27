import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';
import 'otp_verification_screen.dart';

class CompanySignUpScreen extends StatefulWidget {
  const CompanySignUpScreen({super.key});

  @override
  State<CompanySignUpScreen> createState() => _CompanySignUpScreenState();
}

class _CompanySignUpScreenState extends State<CompanySignUpScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController adminNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController exactAddressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? errorText;
  bool isLoading = false;
  bool isResolvingLocation = false;
  double? _selectedLatitude;
  double? _selectedLongitude;

  bool get _hasCompanyLocation =>
      _selectedLatitude != null && _selectedLongitude != null;

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.of(context).push<_PickedCompanyLocation>(
      MaterialPageRoute(
        builder: (_) => _CompanyLocationPickerScreen(
          initialLat: _selectedLatitude,
          initialLng: _selectedLongitude,
          initialAddress: exactAddressController.text.trim(),
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedLatitude = result.lat;
      _selectedLongitude = result.lng;
      if (result.address.trim().isNotEmpty) {
        exactAddressController.text = result.address.trim();
      }
      errorText = null;
    });
  }

  Future<void> _useCurrentLocation() async {
    try {
      setState(() {
        isResolvingLocation = true;
        errorText = null;
      });

      final position = await _determineCurrentPosition();
      if (!mounted) return;

      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => errorText = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => isResolvingLocation = false);
      }
    }
  }

  Future<void> _createCompanyAccount() async {
    final companyName = companyNameController.text.trim();
    final adminName = adminNameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final exactAddress = exactAddressController.text.trim();
    final city = cityController.text.trim();
    final area = areaController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (companyName.isEmpty ||
        adminName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        exactAddress.isEmpty ||
        city.isEmpty ||
        area.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        errorText = 'Please fill all fields';
      });
      return;
    }

    if (!_hasCompanyLocation) {
      setState(() {
        errorText = 'Please pick the company location on the map.';
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
            companyPhone: phone,
            exactAddress: exactAddress,
            companyCity: city,
            companyArea: area,
            companyLat: _selectedLatitude,
            companyLng: _selectedLongitude,
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
    phoneController.dispose();
    exactAddressController.dispose();
    cityController.dispose();
    areaController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
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

  Widget _locationSelector() {
    final statusColor = _hasCompanyLocation
        ? AppColors.success
        : AppColors.warning;
    final statusBg = _hasCompanyLocation
        ? AppColors.successSoft
        : AppColors.warningSoft;
    final statusText = _hasCompanyLocation
        ? 'Company location selected. Coordinates will be saved automatically.'
        : 'Pick the exact company location before creating the account.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _hasCompanyLocation
                      ? Icons.check_circle_outline_rounded
                      : Icons.location_searching_rounded,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: isLoading || isResolvingLocation
                ? null
                : _pickLocationOnMap,
            icon: const Icon(Icons.map_outlined),
            label: Text(
              _hasCompanyLocation
                  ? 'Change Location on Map'
                  : 'Pick Location on Map',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: isLoading || isResolvingLocation
                ? null
                : _useCurrentLocation,
            icon: isResolvingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
            label: Text(
              isResolvingLocation
                  ? 'Finding Location...'
                  : 'Use Current Location',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Company Sign Up'),
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
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create your company account',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Add the company details and choose the exact operating location.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle('Company information'),
                _buildTextField(
                  controller: companyNameController,
                  label: 'Company Name',
                  icon: Icons.business_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: adminNameController,
                  label: 'Admin Name',
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
                  label: 'Company Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle('Company location'),
                _buildTextField(
                  controller: exactAddressController,
                  label: 'Exact Address',
                  icon: Icons.location_on_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: cityController,
                  label: 'City',
                  icon: Icons.location_city_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: areaController,
                  label: 'Area',
                  icon: Icons.map_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                _locationSelector(),
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
                  label: 'Create Company Account',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading || isResolvingLocation
                      ? null
                      : _createCompanyAccount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickedCompanyLocation {
  final double lat;
  final double lng;
  final String address;

  const _PickedCompanyLocation({
    required this.lat,
    required this.lng,
    required this.address,
  });
}

class _CompanyLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String initialAddress;

  const _CompanyLocationPickerScreen({
    required this.initialLat,
    required this.initialLng,
    required this.initialAddress,
  });

  @override
  State<_CompanyLocationPickerScreen> createState() =>
      _CompanyLocationPickerScreenState();
}

class _CompanyLocationPickerScreenState
    extends State<_CompanyLocationPickerScreen> {
  late final TextEditingController _addressController;
  late gmaps.LatLng _selectedLatLng;
  final MapController _desktopMapController = MapController();
  gmaps.GoogleMapController? _mapController;
  double _desktopZoom = 16;
  bool _isLocating = false;
  String? _locationError;

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

  Future<void> _zoomIn() async {
    if (_useGoogleMapsPlugin) {
      final controller = _mapController;
      if (controller == null) return;
      await controller.animateCamera(gmaps.CameraUpdate.zoomIn());
      return;
    }

    final nextZoom = (_desktopZoom + 1).clamp(3.0, 19.0).toDouble();
    setState(() => _desktopZoom = nextZoom);
    _desktopMapController.move(_desktopLatLng, nextZoom);
  }

  Future<void> _zoomOut() async {
    if (_useGoogleMapsPlugin) {
      final controller = _mapController;
      if (controller == null) return;
      await controller.animateCamera(gmaps.CameraUpdate.zoomOut());
      return;
    }

    final nextZoom = (_desktopZoom - 1).clamp(3.0, 19.0).toDouble();
    setState(() => _desktopZoom = nextZoom);
    _desktopMapController.move(_desktopLatLng, nextZoom);
  }

  Future<void> _useCurrentLocation() async {
    try {
      setState(() {
        _isLocating = true;
        _locationError = null;
      });

      final position = await _determineCurrentPosition();
      final nextLatLng = gmaps.LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() => _selectedLatLng = nextLatLng);
      if (_useGoogleMapsPlugin) {
        await _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(nextLatLng, 16),
        );
      } else {
        _desktopZoom = 16;
        _desktopMapController.move(_desktopLatLng, _desktopZoom);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      _PickedCompanyLocation(
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
        onMapCreated: (controller) {
          _mapController = controller;
        },
        markers: {
          gmaps.Marker(
            markerId: const gmaps.MarkerId('company_location'),
            position: _selectedLatLng,
          ),
        },
        onTap: (latLng) {
          setState(() {
            _selectedLatLng = latLng;
            _locationError = null;
          });
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        mapToolbarEnabled: true,
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
            _locationError = null;
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pick Company Location'),
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _addressController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Exact Address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
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
                        _MapCircleButton(icon: Icons.add, onTap: _zoomIn),
                        const SizedBox(height: 8),
                        _MapCircleButton(icon: Icons.remove, onTap: _zoomOut),
                        const SizedBox(height: 8),
                        _MapCircleButton(
                          icon: Icons.my_location_rounded,
                          onTap: _isLocating ? null : _useCurrentLocation,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_locationError != null) ...[
                    Text(
                      _locationError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(
                    'Selected location: ${_selectedLatLng.latitude.toStringAsFixed(6)}, ${_selectedLatLng.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Use This Location',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _confirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _MapCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: onTap == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

Future<Position> _determineCurrentPosition() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied) {
    throw Exception('Location permission was denied.');
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception(
      'Location permission is permanently denied. Enable it from settings.',
    );
  }

  return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
}
