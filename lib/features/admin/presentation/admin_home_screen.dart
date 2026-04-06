import 'package:flutter/material.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Platform Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(title: Text('Approve Companies')),
          ListTile(title: Text('Manage Users')),
          ListTile(title: Text('Disputes')),
        ],
      ),
    );
  }
}
