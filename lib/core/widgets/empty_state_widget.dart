import 'package:flutter/material.dart';
import 'package:wasle/core/theme/app_colors.dart';
import 'package:wasle/core/theme/app_spacing.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primaryLight,
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
