import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/auth_service.dart';
import 'approved_drivers_screen.dart';
import 'company_profile_screen.dart';
import 'driver_requests_screen.dart';

class CompanyDashboardScreen extends StatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  final AuthService _authService = AuthService();

  bool isLoading = true;
  bool isSigningOut = false;
  String? errorText;

  Map<String, dynamic>? profileData;
  Map<String, dynamic>? companyData;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
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
      final driverRequests = await _authService.getDriverRequestsForCurrentCompany();

      if (!mounted) return;

      setState(() {
        profileData = profile;
        companyData = company;
        requests = driverRequests;
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
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSigningOut = false;
        });
      }
    }
  }

  void _openRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DriverRequestsScreen(),
      ),
    );
  }

  void _openApprovedDrivers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ApprovedDriversScreen(),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CompanyProfileScreen(),
      ),
    );
  }

  int _countByStatus(String status) {
    final normalized = status.toLowerCase();
    return requests.where((request) {
      final requestStatus = request['request_status']?.toString().toLowerCase();
      final verificationStatus = request['verification_status']?.toString().toLowerCase();
      return requestStatus == normalized || verificationStatus == normalized;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final companyName = companyData?['name']?.toString() ?? 'Your Company';
    final adminName = profileData?['full_name']?.toString() ?? 'Company Admin';

    final pendingCount = _countByStatus('pending');
    final approvedCount = _countByStatus('approved');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Dashboard'),
        actions: [
          IconButton(
            onPressed: isSigningOut ? null : _signOut,
            tooltip: 'Log Out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
              ? EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load dashboard',
                  message: errorText!,
                  action: SecondaryButton(
                    label: 'Try Again',
                    isExpanded: false,
                    onPressed: _loadDashboard,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x331D4ED8),
                              blurRadius: 24,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COMPANY',
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              companyName,
                              style: AppTextStyles.heading1.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Admin: $adminName',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                _HeroChip(label: '$pendingCount pending'),
                                _HeroChip(label: '$approvedCount approved'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(
                        title: 'Quick Actions',
                        subtitle: 'Manage requests and company account',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'View Driver Requests',
                        icon: Icons.inbox_outlined,
                        onPressed: _openRequests,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        label: 'View Approved Drivers',
                        icon: Icons.verified_user_outlined,
                        onPressed: _openApprovedDrivers,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        label: 'Company Profile',
                        icon: Icons.business_outlined,
                        onPressed: _openProfile,
                      ),
                      const SizedBox(height: AppSpacing.sm),
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
                ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(color: Colors.white),
      ),
    );
  }
}

