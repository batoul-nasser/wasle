import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  final _db = Supabase.instance.client;
  late final Future<Map<String, dynamic>?> _paymentFuture = _loadLatestPayment();

  Future<Map<String, dynamic>?> _loadLatestPayment() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;

    final order = await _db
        .from('orders')
        .select('id, tracking_code, created_at')
        .eq('customer_profile_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (order == null) return null;

    final orderId = order['id']?.toString();
    if (orderId == null || orderId.isEmpty) return {'order': order};
    final payment = await _db
        .from('payments')
        .select('id, method, status, amount')
        .eq('order_id', orderId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return {'order': order, 'payment': payment};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Method'), centerTitle: true),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _paymentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load payment: ${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No payment details found.'));
          }
          final order = data['order'] as Map<String, dynamic>?;
          final payment = data['payment'] as Map<String, dynamic>?;
          final method = payment?['method']?.toString() ?? 'not_set';
          final status = payment?['status']?.toString() ?? 'pending';
          final amount = (payment?['amount'] as num?)?.toDouble();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Order: ${order?['tracking_code']?.toString() ?? order?['id']?.toString() ?? '-'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Payment Method: $method',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Payment Status: $status',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Amount: ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
