import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/driver/data/driver_deliveries_repository.dart';
import 'package:wasle/features/driver/presentation/pages/my_deliveries_screen.dart';
import 'driver_profile_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final AuthService _authService = AuthService();
  final DriverDeliveriesRepository _deliveriesRepository = DriverDeliveriesRepository();

  bool isLoading = true;
  String? errorText;
  int assignedCount = 0;
  int activeCount = 0;
  int completedCount = 0;

  Map<String, dynamic>? profileData;
  Map<String, dynamic>? driverData;
  Map<String, dynamic>? companyData;

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

      await _authService.syncDriverCompanyLinkFromApprovedRequest();

      final profile = await _authService.getProfileById(user.id);
      final driver = await _authService.getDriverByProfileId(user.id);

      Map<String, dynamic>? company;
      final companyId = driver?['company_id'];

      if (companyId != null) {
        company = await _authService.getCompanyById(companyId.toString());
      }

      try {
        final counts = await _deliveriesRepository.getDriverDeliveryCounts();
        assignedCount = counts['assigned'] ?? 0;
        activeCount = counts['active'] ?? 0;
        completedCount = counts['completed'] ?? 0;
      } catch (_) {
        assignedCount = 0;
        activeCount = 0;
        completedCount = 0;
      }

      if (!mounted) return;

      setState(() {
        profileData = profile;
        driverData = driver;
        companyData = company;
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

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DriverProfileScreen(),
      ),
    );
  }

  void _openMyDeliveries() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyDeliveriesScreen(),
      ),
    ).then((_) => _loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final fullName = profileData?['full_name']?.toString() ?? 'Driver';
    final companyName = companyData?['name']?.toString() ?? 'Not assigned';
    final verification = driverData?['verification_status']?.toString() ?? 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline_rounded),
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
                              'DRIVER PORTAL',
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Welcome back, $fullName',
                              style: AppTextStyles.heading1.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              companyName,
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Assigned $assignedCount',
                                    style: AppTextStyles.label.copyWith(color: Colors.white),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Active $activeCount',
                                    style: AppTextStyles.label.copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(
                        title: 'Today Summary',
                        subtitle: 'Quick snapshot of your workflow',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 186,
                        child: Row(
                          children: [
                            Expanded(
                              child: DashboardStatCard(
                                icon: Icons.assignment_turned_in_outlined,
                                value: '$assignedCount',
                                label: 'Assigned Orders',
                                subtitle: 'Ready to pick up',
                              ),
                            ),
                            SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: DashboardStatCard(
                                icon: Icons.check_circle_outline,
                                value: '$completedCount',
                                label: 'Completed',
                                subtitle: 'Delivered today',
                                accentColor: AppColors.success,
                                accentSoftColor: AppColors.successSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DashboardStatCard(
                        icon: Icons.pending_actions_outlined,
                        value: '$activeCount',
                        label: 'Pending Tasks',
                        subtitle: 'Orders in active progress',
                        accentColor: AppColors.warning,
                        accentSoftColor: AppColors.warningSoft,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(
                        title: 'Quick Actions',
                        subtitle: 'Common actions for your account',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'My Deliveries',
                        icon: Icons.local_shipping_outlined,
                        onPressed: _openMyDeliveries,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PrimaryButton(
                        label: 'View Profile',
                        icon: Icons.badge_outlined,
                        onPressed: _openProfile,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        label: 'Refresh Dashboard',
                        icon: Icons.refresh_rounded,
                        onPressed: _loadDashboard,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      InfoCard(
                        title: 'Account State',
                        subtitle: 'Your verification and company details',
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        child: Column(
                          children: [
                            _MetaRow(label: 'Verification', value: verification),
                            const SizedBox(height: AppSpacing.sm),
                            _MetaRow(label: 'Company', value: companyName),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMuted,
          ),
        ),
        StatusChip(
          label: value,
          tone: StatusChip.fromStatus(value),
        ),
      ],
    );
  }
}
