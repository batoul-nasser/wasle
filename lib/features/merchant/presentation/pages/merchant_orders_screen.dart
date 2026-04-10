import 'package:flutter/material.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  final AuthService _authService = AuthService();

  bool isLoading = true;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final data = await _authService.getMerchantOrders();
      if (!mounted) return;

      setState(() {
        orders = data;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No merchant orders',
              message: 'Your created orders will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.xl),
                itemCount: orders.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final order = orders[index];

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order['customer_name']?.toString() ??
                                      'Customer',
                                  style: AppTextStyles.title,
                                ),
                              ),
                              StatusChip(
                                label: order['status']?.toString() ?? 'pending',
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Pickup: ${order['pickup_address'] ?? '-'}',
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Delivery: ${order['delivery_address'] ?? '-'}',
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Phone: ${order['customer_phone'] ?? '-'}',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
