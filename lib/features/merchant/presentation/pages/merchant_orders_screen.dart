import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/ui/ui.dart';

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> orders = [];
  String? errorText;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        isLoading = true;
        errorText = null;
      });

      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() { isLoading = false; errorText = 'Not logged in.'; });
        return;
      }

      final merchantRow = await _client
          .from('merchant_users')
          .select('merchant_id')
          .eq('profile_id', user.id)
          .maybeSingle();

      if (merchantRow == null) {
        setState(() { isLoading = false; errorText = 'Merchant profile not found.'; });
        return;
      }

      final merchantId = merchantRow['merchant_id'] as String;

      // Fetch orders
      final rawOrders = await _client
          .from('orders')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      final orderList = List<Map<String, dynamic>>.from(rawOrders);

      // Fetch payments separately and merge
      if (orderList.isNotEmpty) {
        final orderIds = orderList.map((o) => o['id'].toString()).toList();
        final rawPayments = await _client
            .from('payments')
            .select()
            .inFilter('order_id', orderIds);

        final paymentByOrderId = {
          for (final p in List<Map<String, dynamic>>.from(rawPayments))
            p['order_id'].toString(): p
        };

        for (final order in orderList) {
          order['_payment'] = paymentByOrderId[order['id'].toString()];
        }
      }

      if (!mounted) return;
      setState(() {
        orders = orderList;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { isLoading = false; errorText = 'Failed to load orders: $e'; });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'created': return Colors.blue;
      case 'assigned': return Colors.orange;
      case 'picked_up':
      case 'in_transit': return Colors.purple;
      case 'dropped_at_pickup_point':
      case 'stored_at_pickup_point': return Colors.teal;
      case 'delivered':
      case 'picked_up_by_customer': return Colors.green;
      case 'cancelled':
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'failed': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
          ? Center(child: Text(errorText!, style: const TextStyle(color: Colors.red)))
          : orders.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message: 'Your created orders will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.xl),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final payment = order['_payment'] as Map<String, dynamic>?;

                  final status = order['status']?.toString() ?? 'created';
                  final paymentStatus = payment?['status']?.toString() ?? 'pending';
                  final paymentMethod = payment?['method']?.toString() ?? '';
                  final amount = payment?['amount'];
                  final trackingCode = order['tracking_code']?.toString() ?? '-';
                  final customerName = order['customer_name']?.toString() ?? 'Customer';
                  final customerPhone = order['customer_phone']?.toString() ?? '-';
                  final deliveryAddress = order['customer_address_text']?.toString() ?? '-';
                  final notes = order['notes']?.toString();

                  final methodLabel = paymentMethod == 'cash_at_pickup'
                      ? 'Cash at Pickup'
                      : paymentMethod == 'whish_online'
                      ? 'Whish Online'
                      : '-';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Expanded(child: Text(customerName, style: AppTextStyles.title)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.replaceAll('_', ' '),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('🎫 $trackingCode', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Divider(height: 16),

                          // Customer info
                          Row(children: [
                            const Icon(Icons.phone, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(customerPhone, style: AppTextStyles.body),
                          ]),
                          const SizedBox(height: 4),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(child: Text(deliveryAddress, style: AppTextStyles.body)),
                          ]),
                          if (notes != null && notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.note, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(notes, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                            ]),
                          ],
                          const Divider(height: 16),

                          // Payment info
                          Row(children: [
                            const Icon(Icons.payment, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(methodLabel, style: AppTextStyles.body),
                            const Spacer(),
                            if (amount != null)
                              Text('\$$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _paymentColor(paymentStatus).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                paymentStatus,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _paymentColor(paymentStatus)),
                              ),
                            ),
                          ]),
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