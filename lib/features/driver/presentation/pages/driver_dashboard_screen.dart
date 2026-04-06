import 'package:flutter/material.dart';
import 'package:wasle/features/driver/presentation/pages/driver_profile_screen.dart';
import 'package:wasle/features/driver/presentation/pages/my_deliveries_screen.dart';
import 'package:wasle/features/driver/presentation/pages/update_location_screen.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Widget destination,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
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
      appBar: AppBar(title: const Text('Driver Dashboard'), centerTitle: true),
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
                  'DRIVER PORTAL',
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
                  'Manage your deliveries and account from here.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Today's Summary",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCard(
                icon: Icons.assignment_outlined,
                title: 'Assigned Orders',
                value: '0',
              ),
              const SizedBox(width: 12),
              _buildCard(
                icon: Icons.local_shipping_outlined,
                title: 'Active Deliveries',
                value: '0',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCard(
                icon: Icons.check_circle_outline,
                title: 'Completed',
                value: '0',
              ),
              const SizedBox(width: 12),
              _buildCard(
                icon: Icons.star_outline,
                title: 'Rating',
                value: '4.8',
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
            icon: Icons.local_shipping_outlined,
            label: 'My Deliveries',
            destination: const MyDeliveriesScreen(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            context: context,
            icon: Icons.person_outline,
            label: 'My Profile',
            destination: const DriverProfileScreen(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            context: context,
            icon: Icons.location_on_outlined,
            label: 'Update Location',
            destination: const UpdateLocationScreen(),
          ),
        ],
      ),
    );
  }
}
