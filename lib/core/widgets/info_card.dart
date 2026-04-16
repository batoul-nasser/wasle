import 'package:flutter/material.dart';
import 'package:wasle/core/theme/app_colors.dart';
import 'package:wasle/core/theme/app_spacing.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class InfoCard extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Border? border;

  // Legacy API compatibility
  final String? value;
  final IconData? icon;

  const InfoCard({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.backgroundColor,
    this.border,
    this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || subtitle != null || leading != null || trailing != null;
    final hasLegacyRow = title != null && value != null && child == null &&
        leading == null && subtitle == null && trailing == null;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: border ?? Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: hasLegacyRow
          ? Row(
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
                      Text(title!, style: AppTextStyles.caption),
                      const SizedBox(height: AppSpacing.xs),
                      Text(value!, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasHeader) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null) Text(title!, style: AppTextStyles.title),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(subtitle!, style: AppTextStyles.bodyMuted),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ],
                if (child != null) ...[
                  if (hasHeader) const SizedBox(height: AppSpacing.md),
                  child!,
                ],
                if (!hasHeader && child == null && title != null) Text(title!, style: AppTextStyles.title),
              ],
            ),
    );
  }
}