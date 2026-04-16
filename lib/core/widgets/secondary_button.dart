import 'package:flutter/material.dart';

import 'package:wasle/core/theme/app_colors.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final bool isExpanded;
  final Color borderColor;
  final Color foregroundColor;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 52,
    this.isExpanded = true,
    this.borderColor = AppColors.border,
    this.foregroundColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final buttonChild = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final widget = SizedBox(
      height: height,
      width: isExpanded ? double.infinity : null,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.button,
        ),
        onPressed: isLoading ? null : onPressed,
        child: buttonChild,
      ),
    );

    return isExpanded ? widget : IntrinsicWidth(child: widget);
  }
}