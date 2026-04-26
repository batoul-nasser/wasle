import 'package:flutter/material.dart';
import 'package:wasle/core/services/supabase_service.dart';
import 'package:wasle/features/pickup_point/data/pickup_point_service.dart';

import 'pickup_point_orders_screen.dart';

class PickupPointDashboardScreen extends StatefulWidget {
  const PickupPointDashboardScreen({super.key});

  @override
  State<PickupPointDashboardScreen> createState() =>
      _PickupPointDashboardScreenState();
}

class _PickupPointDashboardScreenState
    extends State<PickupPointDashboardScreen> {
  final _service = PickupPointService();

  bool _loading = true;
  Map<String, dynamic>? _pickupPoint;
  String _ppName = '';
  int _pendingCount = 0;
  double _pendingAmount = 0.0;
  int _completedTodayCount = 0;
  double _completedTodayAmount = 0.0;
  List<Map<String, dynamic>> _recentCompletedOrders = [];

  bool get _showsAgentCollection => _service.usesAgentCollection(_pickupPoint);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      final pp = await _service.getMyPickupPoint();
      final orders = await _service.getPendingCashOrders();
      final total = await _service.getTotalPendingAmount();
      final completed = _service.usesAgentCollection(pp)
          ? await _service.getRecentAgentCollections(
              since: startOfDay,
              limit: 10,
            )
          : await _service.getRecentRemittedOrders(
              since: startOfDay,
              limit: 10,
            );
      final completedTotal = completed.fold<double>(0.0, (sum, row) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        return sum + amount;
      });

      if (!mounted) return;
      setState(() {
        _pickupPoint = pp;
        _ppName = pp?['name']?.toString() ?? 'Pickup Point';
        _pendingCount = orders.length;
        _pendingAmount = total;
        _recentCompletedOrders = completed;
        _completedTodayCount = completed.length;
        _completedTodayAmount = completedTotal;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PICKUP POINT PORTAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _ppName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _showsAgentCollection
                              ? 'View orders waiting for collection by a Wasle agent.'
                              : 'View orders and send collected cash to Wasle.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _stat(
                        Icons.inbox_outlined,
                        'Orders waiting',
                        '$_pendingCount',
                      ),
                      const SizedBox(width: 12),
                      _stat(
                        Icons.payments_outlined,
                        _showsAgentCollection
                            ? 'Awaiting agent'
                            : 'To send Wasle',
                        '\$${_pendingAmount.toStringAsFixed(2)}',
                        valueColor: _pendingAmount > 0
                            ? const Color(0xFFD4800A)
                            : Colors.black87,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stat(
                        Icons.check_circle_outline,
                        _showsAgentCollection
                            ? 'Collected today'
                            : 'Sent today',
                        '$_completedTodayCount',
                        valueColor: _completedTodayCount > 0
                            ? const Color(0xFF0BA360)
                            : Colors.black87,
                      ),
                      const SizedBox(width: 12),
                      _stat(
                        Icons.account_balance_wallet_outlined,
                        _showsAgentCollection
                            ? 'Collected by agent'
                            : 'Sent to Wasle',
                        '\$${_completedTodayAmount.toStringAsFixed(2)}',
                        valueColor: _completedTodayAmount > 0
                            ? const Color(0xFF0BA360)
                            : Colors.black87,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PickupPointOrdersScreen(),
                        ),
                      ).then((_) => _load()),
                      icon: const Icon(Icons.list_alt_outlined),
                      label: Text(
                        _showsAgentCollection
                            ? 'View Orders Awaiting Agent Collection'
                            : 'View Orders with Pending Cash',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  if (_recentCompletedOrders.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      _showsAgentCollection
                          ? 'Today\'s Agent Collections'
                          : 'Today\'s Completed Orders',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _showsAgentCollection
                          ? 'Orders handed to customers and already collected by a Wasle agent.'
                          : 'Orders handed to customers and already sent to Wasle.',
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._recentCompletedOrders.map((entry) {
                      final amount =
                          (entry['amount'] as num?)?.toDouble() ?? 0.0;
                      final tracking =
                          entry['tracking_code']?.toString() ?? '-';
                      final customer =
                          entry['customer_name']?.toString() ?? 'Customer';
                      final phone = entry['customer_phone']?.toString() ?? '-';
                      final whishRef = entry['whish_ref']?.toString() ?? '-';
                      final collectorName =
                          entry['collector_name']?.toString() ?? '';
                      final eventNote = entry['note']?.toString() ?? '';
                      final completedAt = _showsAgentCollection
                          ? entry['created_at']?.toString() ?? ''
                          : entry['sent_at']?.toString() ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(
                              0xFF0BA360,
                            ).withValues(alpha: 0.12),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F7EF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF0BA360),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tracking,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$customer - $phone',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _showsAgentCollection
                                        ? 'Collected by agent: \$${amount.toStringAsFixed(2)}'
                                        : 'Sent to Wasle: \$${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF0BA360),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _showsAgentCollection
                                        ? collectorName.isNotEmpty
                                              ? 'Confirmed by: $collectorName'
                                              : 'Confirmed by pickup point'
                                        : 'Whish ref: $whishRef',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (_showsAgentCollection &&
                                      eventNote.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      eventNote,
                                      style: const TextStyle(
                                        color: Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  if (completedAt.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _showsAgentCollection
                                          ? 'Collected at: $completedAt'
                                          : 'Sent at: $completedAt',
                                      style: const TextStyle(
                                        color: Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (_pendingAmount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF4E2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD4800A).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_outlined,
                            color: Color(0xFFD4800A),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _showsAgentCollection
                                  ? 'You have \$${_pendingAmount.toStringAsFixed(2)} waiting for a Wasle agent to collect.'
                                  : 'You have \$${_pendingAmount.toStringAsFixed(2)} to send to Wasle via Whish.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFD4800A),
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _stat(IconData icon, String title, String value, {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
          children: [
            Icon(icon, size: 28, color: Colors.blue),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
