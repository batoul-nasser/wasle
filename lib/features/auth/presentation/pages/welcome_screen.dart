import 'package:flutter/material.dart';
import 'package:wasle/core/ui/ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(child: Image.asset('assets/images/logo.png', height: 110)),

              const SizedBox(height: AppSpacing.xl),
              Text(
                'Welcome to Wasle',
                style: AppTextStyles.heading1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your Orders Are One Step Closer.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Login',
                icon: Icons.login,
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'Create Account',
                icon: Icons.person_add,
                onPressed: () {
                  Navigator.pushNamed(context, '/sign-up-role');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
