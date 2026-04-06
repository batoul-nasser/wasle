import 'package:flutter/material.dart';
import 'package:wasle/core/theme/app_colors.dart';
import 'package:wasle/core/theme/app_text_styles.dart';

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: AppColors.primary),
      label: Text(
        isLoading ? 'Please wait...' : label,
        style: AppTextStyles.button.copyWith(color: AppColors.primary),
      ),
    );
  }
}
