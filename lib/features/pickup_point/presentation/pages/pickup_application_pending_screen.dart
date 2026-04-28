import 'package:flutter/material.dart';
import 'package:wasle/core/ui/ui.dart';

class PickupApplicationPendingScreen extends StatelessWidget {
  const PickupApplicationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Under Review')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: InfoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 64,
                  color: AppColors.warning,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Your pickup point application is under review',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your request is still pending. You cannot access your pickup point account until an admin reviews and approves your application.',
                  style: AppTextStyles.bodyMuted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                SecondaryButton(
                  label: 'Back To Welcome',
                  icon: Icons.home_outlined,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/welcome',
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
