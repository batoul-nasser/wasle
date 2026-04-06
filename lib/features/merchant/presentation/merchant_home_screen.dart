import 'package:flutter/material.dart';

class MerchantHomeScreen extends StatelessWidget {
  const MerchantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(title: Text('Create Order')),
          ListTile(title: Text('My Orders')),
          ListTile(title: Text('Business Profile')),
        ],
      ),
    );
  }
}
