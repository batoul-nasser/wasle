import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
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
  bool isDeletingAccount = false;
  String? errorText;

  Map<String, dynamic>? profileData;
  Map<String, dynamic>? driverData;
  Map<String, dynamic>? companyData;
  Map<String, dynamic>? latestRequestData;

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
      final latestRequest = await _authService.getLatestDriverRequestSummary();

      Map<String, dynamic>? company;
      final companyId = driver?['company_id']?.toString();
      final requestStatus = latestRequest?['request_status']
          ?.toString()
          .trim()
          .toLowerCase();
      final requestCompanyId = latestRequest?['company_id']?.toString();
      final effectiveCompanyId =
          (companyId != null && companyId.isNotEmpty)
              ? companyId
              : (requestStatus == 'approved' ? requestCompanyId : null);

      if (effectiveCompanyId != null && effectiveCompanyId.isNotEmpty) {
        company = await _authService.getCompanyById(effectiveCompanyId);
      }

      if (!mounted) return;

      setState(() {
        profileData = profile;
        driverData = driver;
        companyData = company;
        latestRequestData = latestRequest;
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

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This will permanently delete your driver account and related driver data. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() {
        isDeletingAccount = true;
      });

      await _authService.deleteCurrentDriverAccount();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isDeletingAccount = false;
        });
      }
    }
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required dynamic value,
    bool showAsStatus = false,
  }) {
    final textValue = value?.toString() ?? '-';

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
      child: Row(
        children: [
          Expanded(child: Text(textValue, style: AppTextStyles.title)),
          if (showAsStatus)
            StatusChip(
              label: textValue,
              tone: StatusChip.fromStatus(textValue),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = profileData?['full_name']?.toString() ?? 'No Name';
    final phone = profileData?['phone'];
    final role = profileData?['role'];
    final driverVerification = driverData?['verification_status']
        ?.toString()
        .trim()
        .toLowerCase();
    final latestRequestStatus = latestRequestData?['request_status']
        ?.toString()
        .trim()
        .toLowerCase();
    final verification = driverVerification == 'approved'
        ? 'approved'
        : (latestRequestStatus == 'approved'
              ? 'approved'
              : (driverData?['verification_status'] ??
                    latestRequestData?['request_status']));
    final company = companyData?['name'] ?? 'Not linked yet';
    final latestRequestStatusText = latestRequestData?['request_status']
        ?.toString();
    final latestRequestCompany = latestRequestData?['company_name']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Profile')),
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
                onPressed: _loadDriverProfile,
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
                          Icons.person_outline_rounded,
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
                              fullName,
                              style: AppTextStyles.heading2.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Driver Account',
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
                  icon: Icons.badge_outlined,
                  label: 'Full Name',
                  value: fullName,
                ),
                const SizedBox(height: AppSpacing.sm),
                _infoTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: phone,
                ),
                const SizedBox(height: AppSpacing.sm),
                _infoTile(
                  icon: Icons.work_outline_rounded,
                  label: 'Role',
                  value: role,
                ),
                const SizedBox(height: AppSpacing.sm),
                _infoTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Verification Status',
                  value: verification,
                  showAsStatus: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                _infoTile(
                  icon: Icons.apartment_rounded,
                  label: 'Company',
                  value: company,
                ),
                if (latestRequestData != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _infoTile(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Latest Company Request',
                    value: latestRequestCompany == null
                        ? latestRequestStatusText
                        : '$latestRequestCompany (${latestRequestStatusText ?? '-'})',
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Log Out',
                  icon: Icons.logout_rounded,
                  backgroundColor: AppColors.danger,
                  isLoading: isSigningOut && !isDeletingAccount,
                  onPressed: isDeletingAccount ? null : _signOut,
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: 'Delete Account',
                  icon: Icons.delete_forever_rounded,
                  borderColor: AppColors.danger,
                  foregroundColor: AppColors.danger,
                  isLoading: isDeletingAccount,
                  onPressed: isSigningOut ? null : _deleteAccount,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
    );
  }
}
