import 'package:flutter/material.dart';
import 'package:wasle/features/auth/presentation/pages/company_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/driver_sign_up_screen.dart';

class SignUpRoleScreen extends StatelessWidget {
  const SignUpRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your role')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverSignUpScreen()),
                );
              },
              child: const Text('Driver'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CompanySignUpScreen(),
                  ),
                );
              },
              child: const Text('Delivery Company'),
            ),
          ],
        ),
      ),
    );
  }
}
