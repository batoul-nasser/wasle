import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/features/agent/data/agent_service.dart';
import 'package:wasle/core/services/supabase_service.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen>
    with SingleTickerProviderStateMixin {
  final AgentService _service = AgentService();
  late TabController _tabController;

  bool _loading = true;
  List<Map<String, dynamic>> _pickupPoints = [];
  List<Map<String, dynamic>> _myHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pps = await _service.getPickupPointsWithPendingCash();
    final history = await _service.getMyCollections();
    if (!mounted) return;
    setState(() {
      _pickupPoints = pps;
      _myHistory = history;
      _loading = false;
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
  }

  double get _totalPending => _pickupPoints.fold(
      0.0, (sum, pp) => sum + ((pp['total_pending'] as num?)?.toDouble() ?? 0.0));

  int get _totalOrders => _pickupPoints.fold(
      0, (sum, pp) => sum + ((pp['order_count'] as int?) ?? 0));

  Future<void> _confirmOrder({
    required Map<String, dynamic> order,
    required Map<String, dynamic> payment,
    required String pickupPointId,
    required String pickupPointName,
  }) async {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final tracking = order['tracking_code']?.toString() ?? order['id'].toString();
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Collection'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Order', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(tracking, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Pickup Point', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(pickupPointName),
              const SizedBox(height: 8),
              const Text('Amount to collect', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Any issue or comment',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('I collected the cash'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.confirmCollection(
        orderId: order['id'].toString(),
        paymentId: payment['id'].toString(),
        amount: amount,
        pickupPointId: pickupPointId,
        note: noteCtrl.text.trim(),
      );
      noteCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Collected \$${amount.toStringAsFixed(2)} from $pickupPointName'),
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
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: SupabaseService.client
            .from('profiles')
            .select('full_name')
            .eq('id', SupabaseService.client.auth.currentUser!.id)
            .single()
            .then((data) => data['full_name']?.toString() ?? 'Agent'),
          builder: (context, snapshot) {
            final name = snapshot.data ?? 'Agent';
            return Text('$name\'s Dashboard');
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _load),
          IconButton(icon: const Icon(Icons.logout_outlined), onPressed: _signOut),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.location_on_outlined), text: 'Collect Cash'),
            Tab(icon: Icon(Icons.history_outlined), text: 'My History'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCollectTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildCollectTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary
          Row(children: [
            _summaryCard(icon: Icons.store_outlined, label: 'Locations', value: '${_pickupPoints.length}', color: Colors.blue),
            const SizedBox(width: 12),
            _summaryCard(icon: Icons.inbox_outlined, label: 'Orders', value: '$_totalOrders', color: Colors.orange),
            const SizedBox(width: 12),
            _summaryCard(icon: Icons.payments_outlined, label: 'Total Cash', value: '\$${_totalPending.toStringAsFixed(0)}', color: Colors.green),
          ]),
          const SizedBox(height: 24),
          if (_pickupPoints.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All clear!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('No pickup points have pending cash right now.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ]),
              ),
            )
          else ...[
            const Text('Pickup Points to Visit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._pickupPoints.map((pp) => _buildPickupPointCard(pp)),
          ],
        ],
      ),
    );
  }

  Widget _buildPickupPointCard(Map<String, dynamic> pp) {
    final ppId = pp['id'].toString();
    final ppName = pp['name']?.toString() ?? 'Pickup Point';
    final address = pp['address_text']?.toString() ?? '';
    final phone = pp['phone']?.toString() ?? '';
    final total = (pp['total_pending'] as num?)?.toDouble() ?? 0.0;
    final orders = (pp['pending_orders'] as List?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.store_outlined, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ppName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(address, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
              Text('${orders.length} order${orders.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ]),
        ),
        ...orders.map((order) {
          final payment = order['payment'] as Map<String, dynamic>? ?? {};
          final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
          final tracking = order['tracking_code']?.toString() ?? order['id'].toString();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tracking, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
              ])),
              OutlinedButton.icon(
                onPressed: () => _confirmOrder(order: order, payment: payment, pickupPointId: ppId, pickupPointName: ppName),
                icon: const Icon(Icons.handshake_outlined, size: 16),
                label: const Text('Collected'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildHistoryTab() {
    if (_myHistory.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No collections yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Your confirmed collections will appear here.', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _myHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = _myHistory[i];
        final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        final ppName = (item['pickup_points'] as Map?)?['name']?.toString() ?? 'Pickup Point';
        final collectedAt = item['collected_at']?.toString() ?? '';
        final note = item['note']?.toString() ?? '';

        DateTime? dt;
        try { dt = DateTime.parse(collectedAt).toLocal(); } catch (_) {}

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ppName, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (note.isNotEmpty) Text(note, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if (dt != null) Text(
                '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ])),
            Text('\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
          ]),
        );
      },
    );
  }

  Widget _summaryCard({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}