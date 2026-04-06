import 'package:flutter/material.dart';
import 'package:wasle/core/theme/app_spacing.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.heading3)),
          if (actionText != null && onActionTap != null)
            TextButton(onPressed: onActionTap, child: Text(actionText!)),
        ],
      ),
    );
  }
}
