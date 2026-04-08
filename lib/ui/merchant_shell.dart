import 'package:flutter/material.dart';
import 'package:wasle/merchant/create_order_screen.dart';
import 'package:wasle/merchant/dashboard_screen.dart';
import 'package:wasle/merchant/issues_screen.dart';
import 'package:wasle/merchant/orders_screen.dart';
import 'package:wasle/merchant/profile_screen.dart';
import 'package:wasle/merchant/services/order_service.dart';

class MerchantShell extends StatefulWidget {
  const MerchantShell({super.key});

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  int _currentIndex = 0;
  String _ordersInitialFilter = 'All';

  @override
  void initState() {
    super.initState();
    orderService.startStream();
  }

  @override
  void dispose() {
    orderService.stopStream();
    super.dispose();
  }

  void _goToTab(int index) {
    setState(() {
      _currentIndex = index;
      if (index != 2) {
        _ordersInitialFilter = 'All';
      }
    });
  }

  void _goToOrdersAll() {
    setState(() {
      _ordersInitialFilter = 'All';
      _currentIndex = 2;
    });
  }

  void _goToOrdersFailed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MerchantIssuesScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        onGoToCreate: () => _goToTab(1),
        onGoToOrders: _goToOrdersAll,
        onGoToExceptions: _goToOrdersFailed,
      ),
      CreateOrderScreen(
        onOrderCreatedNavigate: _goToOrdersAll,
      ),
      OrdersScreen(
        initialFilter: _ordersInitialFilter,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF1A56DB).withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
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