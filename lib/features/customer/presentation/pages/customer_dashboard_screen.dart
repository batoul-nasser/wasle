import 'package:flutter/material.dart';
import 'track_my_order_page.dart';
import 'payment_method_page.dart';
import 'pickup_point_page.dart';

class CustomerDashboardScreen extends StatelessWidget {
  const CustomerDashboardScreen({super.key});

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

  Color _statusColor(String status) {
    switch (status) {
      case 'Arrived at Pickup Point':
        return Colors.green;
      case 'In Transit':
        return Colors.orange;
      case 'Pending':
        return Colors.blueGrey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    const orderId = 'ORD-1024';
    const orderStatus = 'Arrived at Pickup Point';
    const eta = 'Ready for pickup';
    const paymentMethod = 'Cash at Pickup Point';
    const paymentStatus = 'Unpaid';
    const pickupPointName = 'Wasle Pickup Point - Beirut';
    const pickupPointPhone = '+961 70 123 456';
    const pickupPointAddress = 'Hamra Main Street, Beirut';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        centerTitle: true,
      ),
      body: ListView(
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
                  'Track your order, payment, and pickup point details.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Order Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCard(
                icon: Icons.inventory_2_outlined,
                title: 'Active Order',
                value: orderId,
              ),
              const SizedBox(width: 12),
              _buildCard(icon: Icons.schedule, title: 'ETA', value: eta),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCard(
                icon: Icons.payments_outlined,
                title: 'Payment',
                value: paymentStatus,
              ),
              const SizedBox(width: 12),
              _buildCard(
                icon: Icons.local_shipping_outlined,
                title: 'Status',
                value: 'Ready',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection(
            title: 'Current Order',
            children: [
              _buildInfoRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Order ID',
                value: orderId,
              ),
              _buildInfoRow(
                icon: Icons.local_shipping_outlined,
                label: 'Order Status',
                value: orderStatus,
                valueColor: _statusColor(orderStatus),
              ),
              _buildInfoRow(
                icon: Icons.timer_outlined,
                label: 'Estimated Arrival',
                value: eta,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildInfoSection(
            title: 'Payment Details',
            children: [
              _buildInfoRow(
                icon: Icons.credit_card_outlined,
                label: 'Payment Method',
                value: paymentMethod,
              ),
              _buildInfoRow(
                icon: Icons.info_outline,
                label: 'Payment Status',
                value: paymentStatus,
                valueColor: paymentStatus == 'Paid'
                    ? Colors.green
                    : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildInfoSection(
            title: 'Pickup Point Details',
            children: [
              _buildInfoRow(
                icon: Icons.store_mall_directory_outlined,
                label: 'Pickup Point',
                value: pickupPointName,
              ),
              _buildInfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: pickupPointPhone,
              ),
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: pickupPointAddress,
              ),
            ],
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
                MaterialPageRoute(builder: (_) => const TrackMyOrderPage()),
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
                MaterialPageRoute(builder: (_) => const PaymentMethodPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            context: context,
            icon: Icons.store_outlined,
            label: 'Pickup Point Details',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PickupPointPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
