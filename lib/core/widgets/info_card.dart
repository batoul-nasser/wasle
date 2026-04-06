import 'package:flutter/material.dart';
import 'package:wasle/core/theme/app_colors.dart';
import 'package:wasle/core/theme/app_spacing.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryLight,
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                Text(value, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
