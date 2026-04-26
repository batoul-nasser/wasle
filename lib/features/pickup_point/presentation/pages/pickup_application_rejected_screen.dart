import 'package:flutter/material.dart';
import 'package:wasle/core/ui/ui.dart';

class PickupApplicationRejectedScreen extends StatelessWidget {
  const PickupApplicationRejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Rejected')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: InfoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cancel_outlined,
                  size: 64,
                  color: AppColors.danger,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Your pickup point application was rejected',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Please contact support or resubmit your application with clearer business and identity documents.',
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
