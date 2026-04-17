import 'package:flutter/material.dart';
import 'package:wasle/features/pickup_point/data/pickup_point_service.dart';
import 'send_to_wasle_screen.dart';

class PickupPointOrdersScreen extends StatefulWidget {
  const PickupPointOrdersScreen({super.key});

  @override
  State<PickupPointOrdersScreen> createState() =>
      _PickupPointOrdersScreenState();
}

class _PickupPointOrdersScreenState extends State<PickupPointOrdersScreen> {
  final _service = PickupPointService();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _service.getPendingCashOrders();
    if (mounted) setState(() { _orders = orders; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
          title: const Text('Orders — Pending Cash'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(
                  child: Text('No orders waiting for cash payment.',
                      style: TextStyle(color: Colors.black54)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final order = _orders[i];
                      final payment =
                          order['payment'] as Map<String, dynamic>;
                      final amount =
                          (payment['amount'] as num).toDouble();
                      final tracking =
                          order['tracking_code']?.toString() ?? '—';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 8,
                              offset: Offset(0, 3))],
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(tracking,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                'Cash to send Wasle: \$${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Color(0xFFD4800A),
                                    fontWeight: FontWeight.w600),
                              ),
                            ]),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SendToWasleScreen(
                                  orderId: order['id'].toString(),
                                  paymentId: payment['id'].toString(),
                                  amount: amount,
                                  trackingCode: tracking,
                                ),
                              ),
                            ).then((_) => _load()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Send to Wasle'),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}