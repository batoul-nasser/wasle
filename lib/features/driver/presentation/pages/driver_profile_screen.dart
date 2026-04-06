import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final AuthService _authService = AuthService();

  bool isLoading = true;
  bool isSigningOut = false;
  String? errorText;

  Map<String, dynamic>? profileData;
  Map<String, dynamic>? driverData;
  Map<String, dynamic>? companyData;
  Map<String, dynamic>? locationData;

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
  }

  Future<void> _loadDriverProfile() async {
    try {
      final user = _authService.currentUser;

      if (user == null) {
        setState(() {
          isLoading = false;
          errorText = 'User not found';
        });
        return;
      }

      final profile = await _authService.getProfileById(user.id);
      final driver = await _authService.getDriverByProfileId(user.id);

      Map<String, dynamic>? company;
      Map<String, dynamic>? location;

      final companyId = driver?['company_id'];
      final driverId = driver?['id'];

      if (companyId != null) {
        company = await _authService.getCompanyById(companyId.toString());
      }

      if (driverId != null) {
        location = await _authService.getDriverLocationByDriverId(
          driverId.toString(),
        );
      }

      if (!mounted) return;

      setState(() {
        profileData = profile;
        driverData = driver;
        companyData = company;
        locationData = location;
        isLoading = false;
        errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() {
        isSigningOut = true;
      });

      await _authService.signOut();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isSigningOut = false;
        });
      }
    }
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.12),
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'approved' || s == 'verified' || s == 'active') {
      return Colors.green;
    }
    if (s == 'pending') {
      return Colors.orange;
    }
    if (s == 'rejected' || s == 'blocked') {
      return Colors.red;
    }
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final fullName = profileData?['full_name']?.toString() ?? 'No Name';
    final phone = profileData?['phone']?.toString() ?? '-';
    final role = profileData?['role']?.toString() ?? '-';
    final verification =
        driverData?['verification_status']?.toString() ?? 'pending';
    final company = companyData?['name']?.toString() ?? '-';
    final city = locationData?['city']?.toString() ?? '-';
    final lat = locationData?['lat'];
    final lng = locationData?['lng'];

    final coordinates = (lat == null || lng == null)
        ? '-'
        : '${lat.toString()}, ${lng.toString()}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Driver Profile'), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDriverProfile,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Driver Account',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Full Name',
                  value: fullName,
                ),
                _buildInfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: phone,
                ),
                _buildInfoTile(
                  icon: Icons.work_outline,
                  label: 'Role',
                  value: role,
                ),
                _buildInfoTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Verification Status',
                  value: verification,
                  valueColor: _statusColor(verification),
                ),
                _buildInfoTile(
                  icon: Icons.apartment_outlined,
                  label: 'Company',
                  value: company,
                ),
                _buildInfoTile(
                  icon: Icons.location_city_outlined,
                  label: 'City',
                  value: city,
                ),
                _buildInfoTile(
                  icon: Icons.pin_drop_outlined,
                  label: 'Coordinates',
                  value: coordinates,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isSigningOut ? null : _signOut,
                    icon: isSigningOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                    label: Text(isSigningOut ? 'Logging out...' : 'Log Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
