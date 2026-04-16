import 'package:flutter/material.dart';

import 'package:wasle/core/theme/app_colors.dart';

enum StatusChipTone {
  info,
  success,
  warning,
  danger,
  neutral,
}

class StatusChip extends StatelessWidget {
  final String label;
  final StatusChipTone tone;

  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusChipTone.neutral,
  });

  static StatusChipTone fromStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    switch (normalized) {
      case 'approved':
      case 'completed':
      case 'delivered':
      case 'dropped_at_pickup_point':
      case 'returned_to_store':
      case 'active':
        return StatusChipTone.success;
      case 'pending':
      case 'created':
      case 'pending_driver_receipt':
      case 'assigned':
      case 'ready_for_driver_pickup':
      case 'rescheduled':
        return StatusChipTone.warning;
      case 'driver_received_order':
      case 'picked_up':
      case 'in_transit':
      case 'returning_to_store':
        return StatusChipTone.info;
      case 'rejected':
      case 'failed':
      case 'cancelled':
      case 'canceled':
        return StatusChipTone.danger;
      default:
        return StatusChipTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteByTone(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  _ChipPalette _paletteByTone(StatusChipTone value) {
    switch (value) {
      case StatusChipTone.info:
        return const _ChipPalette(
          foreground: AppColors.info,
          background: AppColors.infoSoft,
          border: Color(0xFFCFE0FF),
        );
      case StatusChipTone.success:
        return const _ChipPalette(
          foreground: AppColors.success,
          background: AppColors.successSoft,
          border: Color(0xFFBEECCB),
        );
      case StatusChipTone.warning:
        return const _ChipPalette(
          foreground: AppColors.warning,
          background: AppColors.warningSoft,
          border: Color(0xFFFDE68A),
        );
      case StatusChipTone.danger:
        return const _ChipPalette(
          foreground: AppColors.danger,
          background: AppColors.dangerSoft,
          border: Color(0xFFFECACA),
        );
      case StatusChipTone.neutral:
        return const _ChipPalette(
          foreground: AppColors.textSecondary,
          background: AppColors.surfaceMuted,
          border: AppColors.border,
        );
    }
  }
}

class _ChipPalette {
  final Color foreground;
  final Color background;
  final Color border;

  const _ChipPalette({
    required this.foreground,
    required this.background,
    required this.border,
  });
}