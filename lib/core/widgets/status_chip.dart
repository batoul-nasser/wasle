import 'package:flutter/material.dart';
import 'package:wasle/core/theme/app_colors.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class StatusChip extends StatelessWidget {
  final String label;

  const StatusChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();

    Color bg;
    Color text;

    if (lower.contains('approved') || lower.contains('completed')) {
      bg = AppColors.approvedBg;
      text = AppColors.approvedText;
    } else if (lower.contains('rejected') || lower.contains('cancelled')) {
      bg = AppColors.rejectedBg;
      text = AppColors.rejectedText;
    } else {
      bg = AppColors.pendingBg;
      text = AppColors.pendingText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
