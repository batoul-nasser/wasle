import 'package:flutter/material.dart';
import 'package:wasle/features/auth/presentation/pages/company_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/customer_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/driver_sign_up_screen.dart';
// Add these when you create them:
/// import 'package:wasle/features/auth/presentation/pages/merchant_sign_up_screen.dart';
/// import 'package:wasle/features/auth/presentation/pages/pickup_point_sign_up_screen.dart';

class SignUpRoleScreen extends StatelessWidget {
  const SignUpRoleScreen({super.key});

  Widget _buildRoleButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget screen,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your role')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            _buildRoleButton(
              context: context,
              title: 'Driver',
              icon: Icons.local_shipping_outlined,
              screen: const DriverSignUpScreen(),
            ),
            const SizedBox(height: 16),
            _buildRoleButton(
              context: context,
              title: 'Delivery Company',
              icon: Icons.business_outlined,
              screen: const CompanySignUpScreen(),
            ),
            const SizedBox(height: 16),
            _buildRoleButton(
              context: context,
              title: 'Customer',
              icon: Icons.person_outline,
              screen: const CustomerSignUpScreen(),
            ),

            // Add these later when the screens exist:
            /*
            const SizedBox(height: 16),
            _buildRoleButton(
              context: context,
              title: 'Merchant',
              icon: Icons.store_outlined,
              screen: const MerchantSignUpScreen(),
            ),
            const SizedBox(height: 16),
            _buildRoleButton(
              context: context,
              title: 'Pickup Point',
              icon: Icons.location_on_outlined,
              screen: const PickupPointSignUpScreen(),
            ),
            */
          ],
        ),
      ),
    );
  }
}
