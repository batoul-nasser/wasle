import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final AuthService _authService = AuthService();

  bool isLoading = true;
  bool isSigningOut = false;
  String? errorText;

  Map<String, dynamic>? profileData;
  Map<String, dynamic>? companyData;

  @override
  void initState() {
    super.initState();
    _loadCompanyProfile();
  }

  Future<void> _loadCompanyProfile() async {
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
      final company = await _authService.getCompanyById(user.id);

      if (!mounted) return;

      setState(() {
        profileData = profile;
        companyData = company;
        isLoading = false;
        errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorText = e.toString();
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
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
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

  Widget _infoTile({
    required IconData icon,
    required String label,
    required dynamic value,
  }) {
    return InfoCard(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      title: label,
      child: Text(value?.toString() ?? '-', style: AppTextStyles.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyName = companyData?['name']?.toString() ?? 'No company name';

    return Scaffold(
      appBar: AppBar(title: const Text('Company Profile')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
          ? EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load profile',
              message: errorText!,
              action: SecondaryButton(
                label: 'Try Again',
                isExpanded: false,
                onPressed: _loadCompanyProfile,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.business_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              companyName,
                              style: AppTextStyles.heading2.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Company Admin Profile',
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
                _infoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Admin Name',
                  value: profileData?['full_name'],
                ),
                const SizedBox(height: AppSpacing.sm),
                _infoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profileData?['email'],
                ),
                const SizedBox(height: AppSpacing.sm),
                _infoTile(
                  icon: Icons.work_outline_rounded,
                  label: 'Role',
                  value: profileData?['role'],
                ),
                const SizedBox(height: AppSpacing.sm),
                _infoTile(
                  icon: Icons.business_center_outlined,
                  label: 'Company Name',
                  value: companyData?['name'],
                ),
                const SizedBox(height: AppSpacing.sm),
                _infoTile(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value:
                      companyData?['address_text'] ?? companyData?['location'],
                ),
                if (companyData?['lat'] != null &&
                    companyData?['lng'] != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _infoTile(
                    icon: Icons.map_outlined,
                    label: 'Coordinates',
                    value: '${companyData?['lat']}, ${companyData?['lng']}',
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Log Out',
                  icon: Icons.logout_rounded,
                  backgroundColor: AppColors.danger,
                  isLoading: isSigningOut,
                  onPressed: _signOut,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}
