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
  String _ppName = '';
  int _pendingCount = 0;
  double _pendingAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pp = await _service.getMyPickupPoint();
      final orders = await _service.getPendingCashOrders();
      final total = await _service.getTotalPendingAmount();
      if (!mounted) return;
      setState(() {
        _ppName = pp?['name']?.toString() ?? 'Pickup Point';
        _pendingCount = orders.length;
        _pendingAmount = total;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
                          const Text('PICKUP POINT PORTAL',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text(_ppName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text(
                              'View orders and send collected cash to Wasle.',
                              style: TextStyle(color: Colors.white70)),
                        ]),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    _stat(Icons.inbox_outlined, 'Orders waiting',
                        '$_pendingCount'),
                    const SizedBox(width: 12),
                    _stat(
                      Icons.payments_outlined,
                      'To send Wasle',
                      '\$${_pendingAmount.toStringAsFixed(2)}',
                      valueColor: _pendingAmount > 0
                          ? const Color(0xFFD4800A)
                          : Colors.black87,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const PickupPointOrdersScreen()),
                      ).then((_) => _load()),
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('View Orders with Pending Cash'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  if (_pendingAmount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF4E2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                const Color(0xFFD4800A).withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_outlined,
                            color: Color(0xFFD4800A), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You have \$${_pendingAmount.toStringAsFixed(2)} to send to Wasle via Whish.',
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFD4800A),
                                fontWeight: FontWeight.w600,
                                height: 1.4),
                          ),
                        ),
                      ]),
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
          boxShadow: const [BoxShadow(
              color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(children: [
          Icon(icon, size: 28, color: Colors.blue),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black87)),
          const SizedBox(height: 6),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
      ),
    );
  }
}