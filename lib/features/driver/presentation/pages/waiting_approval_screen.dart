import 'dart:async';

import 'package:flutter/material.dart';

import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/core/ui/ui.dart';

class WaitingApprovalScreen extends StatefulWidget {
  const WaitingApprovalScreen({super.key});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen> {
  final AuthService _authService = AuthService();
  Timer? _statusPollingTimer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _startPollingApprovalStatus();
  }

  void _startPollingApprovalStatus() {
    unawaited(_checkAndNavigateIfApproved());
    _statusPollingTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => unawaited(_checkAndNavigateIfApproved()),
    );
  }

  Future<void> _checkAndNavigateIfApproved() async {
    if (!mounted || _isNavigating) return;

    try {
      final status = await _authService.checkDriverStatus();
      final requestStatus = await _authService.getLatestDriverRequestStatus();

      final normalizedStatus = status?.trim().toLowerCase();
      final normalizedRequestStatus = requestStatus?.trim().toLowerCase();

      if (!mounted || _isNavigating) return;

      if (normalizedStatus == 'approved' ||
          normalizedRequestStatus == 'approved') {
        _isNavigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/driver-dashboard',
          (route) => false,
        );
        return;
      }

      if (normalizedStatus == 'rejected' ||
          normalizedRequestStatus == 'rejected') {
        _isNavigating = true;
        Navigator.pushNamedAndRemoveUntil(context, '/rejected', (route) => false);
      }
    } catch (_) {
      // Keep polling quietly; transient network issues should not block UI.
    }
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    super.dispose();
  }

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
                    'Your driver account has been created and is currently under review.',
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
                    label: 'Back to Home',
                    icon: Icons.home_outlined,
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
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
