import 'package:flutter/material.dart';

class ChooseRoleScreen extends StatelessWidget {
  const ChooseRoleScreen({super.key});

  void _go(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoleRegistrationScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your role')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () => _go(context, 'driver'),
            child: const Text('Driver'),
          ),
          ElevatedButton(
            onPressed: () => _go(context, 'merchant'),
            child: const Text('Merchant'),
          ),
          ElevatedButton(
            onPressed: () => _go(context, 'customer'),
            child: const Text('Customer'),
          ),
          ElevatedButton(
            onPressed: () => _go(context, 'delivery_company_admin'),
            child: const Text('Delivery Company'),
          ),
        ],
      ),
    );
  }
}

class RoleRegistrationScreen extends StatelessWidget {
  final String role;
  const RoleRegistrationScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(child: Text('Registration form for role: $role')),
    );
  }
}
