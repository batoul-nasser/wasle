import 'package:flutter/material.dart';
import 'driver_sign_up_screen.dart';
import 'company_sign_up_screen.dart';

class SignUpRoleScreen extends StatelessWidget {
  const SignUpRoleScreen({super.key});

  static const Color blue = Color(0xFF2F80FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Account Type'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverSignUpScreen(),
                    ),
                  );
                },
                child: const Text('Sign Up as Driver'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CompanySignUpScreen(),
                    ),
                  );
                },
                child: const Text('Sign Up as Delivery Company'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}