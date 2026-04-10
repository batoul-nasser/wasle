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
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final loadedProfile = await _authService.getCurrentProfile();
      final loadedOrders = await _authService.getMerchantOrders();

      if (!mounted) return;

      setState(() {
        profile = loadedProfile;
        orders = loadedOrders;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = profile?['full_name']?.toString() ?? 'Merchant';

    final totalOrders = orders.length;
    final pendingOrders = orders
        .where((o) => (o['status'] ?? '').toString().toLowerCase() == 'pending')
        .length;
    final completedOrders = orders
        .where(
          (o) => (o['status'] ?? '').toString().toLowerCase() == 'completed',
        )
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Dashboard')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $fullName',
                          style: AppTextStyles.heading3.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
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
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.25,
                    children: [
                      DashboardStatCard(
                        title: 'Total Orders',
                        value: '$totalOrders',
                        icon: Icons.inventory_2_outlined,
                      ),
                      DashboardStatCard(
                        title: 'Pending',
                        value: '$pendingOrders',
                        icon: Icons.pending_actions_outlined,
                      ),
                      DashboardStatCard(
                        title: 'Completed',
                        value: '$completedOrders',
                        icon: Icons.check_circle_outline,
                      ),
                      const DashboardStatCard(
                        title: 'Role',
                        value: 'Merchant',
                        icon: Icons.storefront_outlined,
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
                        .take(5)
                        .map(
                          (order) => Card(
                            child: ListTile(
                              title: Text(
                                order['customer_name']?.toString() ??
                                    'Customer',
                              ),
                              subtitle: Text(
                                order['delivery_address']?.toString() ??
                                    'No address',
                              ),
                              trailing: StatusChip(
                                label: order['status']?.toString() ?? 'pending',
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}
