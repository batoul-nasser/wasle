import 'package:flutter/material.dart';
import 'package:wasle/core/theme/app_colors.dart';
import 'package:wasle/core/theme/app_spacing.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.heading2),
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: card,
    );
  }
}
