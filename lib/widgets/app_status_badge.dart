import 'package:flutter/material.dart';
import 'package:wasle/core/app_theme.dart';

class AppStatusBadge extends StatelessWidget {
  final String status;

  const AppStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;

    switch (status) {
      case 'created':
        color = Colors.grey;
        label = 'Created';
        break;
      case 'assigned':
        color = AppTheme.primary;
        label = 'Assigned';
        break;
      case 'delivered':
        color = AppTheme.success;
        label = 'Delivered';
        break;
      case 'failed':
        color = AppTheme.danger;
        label = 'Failed';
        break;
      default:
        color = AppTheme.warning;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}