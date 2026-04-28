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
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _pickupPoint;
  bool _loading = true;

  bool get _showsAgentCollection => _service.usesAgentCollection(_pickupPoint);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pickupPoint = await _service.getMyPickupPoint();
    final orders = await _service.getPendingCashOrders();
    final history = await _service.getCollectedOrdersHistory();
    if (!mounted) return;
    setState(() {
      _pickupPoint = pickupPoint;
      _orders = orders;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _confirmAgentCollected(Map<String, dynamic> order) async {
    final payment = order['payment'] as Map<String, dynamic>;
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final tracking =
        order['tracking_code']?.toString() ?? order['id'].toString();
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Cash Ready for Agent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order: $tracking',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Cash ready for collection: \$${amount.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFFD4800A)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Any note for the agent',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Cash ready for agent'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      noteCtrl.dispose();
      return;
    }

    try {
      await _service.confirmCollectedByAgent(
        orderId: order['id'].toString(),
        paymentId: payment['id'].toString(),
        amount: amount,
        note: noteCtrl.text.trim(),
      );
      noteCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Marked $tracking as ready for Wasle agent collection.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      noteCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          _showsAgentCollection
              ? 'Orders - Awaiting Agent'
              : 'Orders - Pending Cash',
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_orders.isEmpty)
                    Text(
                      _showsAgentCollection
                          ? 'No orders are currently waiting for agent collection.'
                          : 'No orders waiting for cash payment.',
                      style: const TextStyle(color: Colors.black54),
                    )
                  else
                    ..._orders.map((order) {
                      final payment = order['payment'] as Map<String, dynamic>;
                      final amount = (payment['amount'] as num).toDouble();
                      final tracking = order['tracking_code']?.toString() ?? '-';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildActiveCard(order, payment, amount, tracking),
                      );
                    }),
                  const SizedBox(height: 20),
                  const Text(
                    'Collected Orders History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    const Text(
                      'No collected history yet.',
                      style: TextStyle(color: Colors.black54),
                    )
                  else
                    ..._history.map((row) {
                      final tracking = row['tracking_code']?.toString() ?? '-';
                      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
                      final status = row['payment_status']?.toString() ?? '';
                      final source = row['source']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tracking,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${amount.toStringAsFixed(2)} - $status',
                                      style: const TextStyle(
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                source == 'agent_collection'
                                    ? 'Agent'
                                    : 'Whish',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildActiveCard(
    Map<String, dynamic> order,
    Map<String, dynamic> payment,
    double amount,
    String tracking,
  ) {
    final collectionStatus =
        order['agent_collection_status']?.toString().toLowerCase();
    final waitingForAgent = collectionStatus == 'ready_for_agent';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracking,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _showsAgentCollection
                      ? (waitingForAgent
                          ? 'Waiting for agent collection: \$${amount.toStringAsFixed(2)}'
                          : 'Cash waiting for agent collection: \$${amount.toStringAsFixed(2)}')
                      : 'Cash to send Wasle: \$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFD4800A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _showsAgentCollection
              ? OutlinedButton.icon(
                  onPressed: waitingForAgent ? null : () => _confirmAgentCollected(order),
                  icon: const Icon(Icons.handshake_outlined, size: 16),
                  label: const Text('Cash ready for agent'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
              : ElevatedButton(
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Send to Wasle'),
                ),
        ],
      ),
    );
  }
}
