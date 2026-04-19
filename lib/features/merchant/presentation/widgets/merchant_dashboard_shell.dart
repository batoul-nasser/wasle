import 'package:flutter/material.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_create_order_screen.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_dashboard_screen.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_orders_screen.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_profile_screen.dart';

class MerchantDashboardShell extends StatefulWidget {
  const MerchantDashboardShell({super.key});

  @override
  State<MerchantDashboardShell> createState() => _MerchantDashboardShellState();
}

class _MerchantDashboardShellState extends State<MerchantDashboardShell> {
  int currentIndex = 0;

  late final List<Widget> pages = [
    MerchantDashboardScreen(
      onOpenCreate: () => _goToTab(1),
      onOpenOrders: () => _goToTab(2),
    ),
    const MerchantCreateOrderScreen(),
    const MerchantOrdersScreen(),
    const MerchantProfileScreen(),
  ];

  void _goToTab(int index) {
    if (!mounted) return;
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Create Order',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
