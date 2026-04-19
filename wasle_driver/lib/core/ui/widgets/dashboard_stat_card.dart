import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String subtitle;
  final Color accentColor;
  final Color accentSoftColor;

  const DashboardStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.subtitle,
    this.accentColor = AppColors.primary,
    this.accentSoftColor = AppColors.primarySoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentSoftColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            value,
            style: AppTextStyles.heading1.copyWith(color: accentColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: AppTextStyles.bodyMuted),
        ],
      ),
    );
  }
}
