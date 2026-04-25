// File: lib/features/merchant/presentation/pages/merchant_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  final AuthService _authService = AuthService();

  bool isLoading = true;
  String? errorText;
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });
      final loadedProfile = await _authService.getCurrentProfile();
      final loadedOrders = await _authService.getMerchantOrders();

      if (!mounted) return;
      setState(() {
        profile = loadedProfile;
        orders = loadedOrders;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorText = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = profile?['full_name']?.toString() ?? 'Merchant';

    final totalOrders = orders.length;
    final pendingOrders = orders
        .where(
          (o) => !{
            'delivered',
            'cancelled',
            'returned_to_store',
          }.contains(o['status']?.toString().toLowerCase()),
        )
        .length;
    final completedOrders = orders
        .where((o) => o['status']?.toString().toLowerCase() == 'delivered')
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Dashboard')),
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
                onPressed: _loadData,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MERCHANT PORTAL',
                          style: AppTextStyles.label.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Welcome, $fullName',
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Manage your orders and monitor activity.',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Stat cards (3-column row)
                  Row(
                    children: [
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.inventory_2_outlined,
                          value: '$totalOrders',
                          label: 'Total Orders',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.pending_actions_outlined,
                          value: '$pendingOrders',
                          label: 'In Progress',
                          accentColor: AppColors.warning,
                          accentSoftColor: AppColors.warningSoft,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.check_circle_outline,
                          value: '$completedOrders',
                          label: 'Delivered',
                          accentColor: AppColors.success,
                          accentSoftColor: AppColors.successSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const SectionHeader(title: 'Recent Orders'),
                  const SizedBox(height: AppSpacing.sm),
                  if (orders.isEmpty)
                    const EmptyStateWidget(
                      icon: Icons.store_outlined,
                      title: 'No orders yet',
                      message:
                          'Create your first order from the Create Order tab.',
                    )
                  else
                    ...orders
                        .take(10)
                        .map(
                          (order) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: InfoCard(
                              title:
                                  order['customer_name']?.toString() ??
                                  order['tracking_code']?.toString() ??
                                  'Order',
                              subtitle:
                                  order['customer_address_text']?.toString() ??
                                  order['customer_phone']?.toString() ??
                                  '',
                              trailing: StatusChip(
                                label: _formatStatus(
                                  order['status']?.toString(),
                                ),
                                tone: StatusChip.fromStatus(
                                  order['status']?.toString(),
                                ),
                              ),
                              child: Text(
                                'Placed: ${_formatDate(order['created_at']?.toString())}',
                                style: AppTextStyles.caption,
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }

  String _formatStatus(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}
