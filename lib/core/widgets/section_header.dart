import 'package:flutter/material.dart';

import 'package:wasle/core/theme/app_spacing.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  // Legacy API compatibility
  final String? actionText;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAction = actionLabel ?? actionText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.heading2),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle!, style: AppTextStyles.bodyMuted),
                ],
              ],
            ),
          ),
          if (resolvedAction != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(resolvedAction),
            ),
        ],
      ),
    );
  }
}