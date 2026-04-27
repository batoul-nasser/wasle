import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/driver/presentation/pages/driver_profile_screen.dart';

class WaitingApprovalScreen extends StatelessWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: InfoCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 40,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Waiting for Approval',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading1,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your request to join a delivery company has been sent and is currently under review.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'You will be able to access active deliveries after approval.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Open Profile',
                    icon: Icons.person_outline_rounded,
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverProfileScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
