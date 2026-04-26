import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/customer/presentation/pages/payment_method_page.dart';
import 'package:wasle/features/customer/presentation/pages/pickup_point_page.dart';
import 'package:wasle/features/customer/presentation/pages/track_my_order_page.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  final AuthService _authService = AuthService();

  bool _loading = true;
  List<Map<String, dynamic>> _recentPickupPoints = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pickupPoints = await _authService.getCustomerRecentPickupPoints(
        limit: 3,
      );
      if (!mounted) return;
      setState(() {
        _recentPickupPoints = pickupPoints;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        centerTitle: true,
      ),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUSTOMER PORTAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Welcome back!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'See your recent pickup points and order tools.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildCard(
                        icon: Icons.store_mall_directory_outlined,
                        title: 'Recent Pickup Points',
                        value: '${_recentPickupPoints.length}',
                      ),
                      const SizedBox(width: 12),
                      _buildCard(
                        icon: Icons.history_outlined,
                        title: 'Saved History',
                        value: _recentPickupPoints.isEmpty ? 'No' : 'Yes',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildInfoSection(
                    title: 'Recently Used Pickup Points',
                    children: _recentPickupPoints.isEmpty
                        ? const [
                            Text(
                              'No pickup points used yet.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ]
                        : _recentPickupPoints.map((point) {
                            final addressParts =
                                [
                                      point['address_text']?.toString().trim(),
                                      point['city']?.toString().trim(),
                                      point['area']?.toString().trim(),
                                    ]
                                    .whereType<String>()
                                    .where((part) => part.isNotEmpty)
                                    .toList();

                            return Column(
                              children: [
                                _buildInfoRow(
                                  icon: Icons.store_outlined,
                                  label: 'Pickup Point',
                                  value:
                                      point['name']?.toString() ??
                                      'Pickup Point',
                                ),
                                _buildInfoRow(
                                  icon: Icons.location_on_outlined,
                                  label: 'Address',
                                  value: addressParts.isEmpty
                                      ? '-'
                                      : addressParts.join(', '),
                                ),
                                _buildInfoRow(
                                  icon: Icons.phone_outlined,
                                  label: 'Phone',
                                  value: point['phone']?.toString() ?? '-',
                                ),
                                if (point != _recentPickupPoints.last)
                                  const Divider(height: 24),
                              ],
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context: context,
                    icon: Icons.location_searching_outlined,
                    label: 'Track My Order',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrackMyOrderPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context: context,
                    icon: Icons.payments_outlined,
                    label: 'Payment Method',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaymentMethodPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context: context,
                    icon: Icons.store_outlined,
                    label: 'Pickup Point History',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PickupPointPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
