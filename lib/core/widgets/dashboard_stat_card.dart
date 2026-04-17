import 'package:flutter/material.dart';
import 'package:wasle/core/theme/app_colors.dart';
import 'package:wasle/core/theme/app_spacing.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String? value;

  // New API
  final String? label;
  final String? subtitle;
  final Color accentColor;
  final Color accentSoftColor;

  // Legacy API compatibility
  final String? title;
  final VoidCallback? onTap;

  const DashboardStatCard({
    super.key,
    required this.icon,
    this.value,
    this.label,
    this.subtitle,
    this.accentColor = AppColors.primary,
    this.accentSoftColor = AppColors.primarySoft,
    this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label ?? title ?? '';
    final resolvedValue = value ?? '-';
    final resolvedSubtitle = subtitle ?? '';

    final card = Container(
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
            resolvedValue,
            style: AppTextStyles.heading1.copyWith(color: accentColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(resolvedLabel, style: AppTextStyles.title),
          if (resolvedSubtitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(resolvedSubtitle, style: AppTextStyles.bodyMuted),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
    );
  }
}