import 'package:flutter/material.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(title: Text('Track Order')),
          ListTile(title: Text('My Orders')),
          ListTile(title: Text('Addresses')),
        ],
      ),
    );
  }
}
