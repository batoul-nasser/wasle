import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
import '../../data/models/driver_delivery.dart';

class DeliveryOrderCard extends StatelessWidget {
  final DriverDelivery delivery;
  final VoidCallback? onTap;

  const DeliveryOrderCard({
    super.key,
    required this.delivery,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: delivery.trackingCode,
      subtitle: delivery.merchantName,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.local_shipping_outlined,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      trailing: StatusChip(
        label: _statusLabel(delivery.status),
        tone: StatusChip.fromStatus(delivery.status),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(
            icon: Icons.pin_drop_outlined,
            text: '${delivery.pickupPointName} - ${delivery.pickupAddress}',
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoLine(
            icon: Icons.outlined_flag_rounded,
            text: 'Dropoff: ${delivery.dropoffAddress ?? '-'}',
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoLine(
            icon: Icons.person_outline_rounded,
            text: '${delivery.customerName} - ${delivery.customerPhone}',
          ),
          if (onTap != null) ...[
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'View Details',
              icon: Icons.arrow_forward_rounded,
              onPressed: onTap,
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'created':
      case 'ready_for_driver_pickup':
      case 'assigned':
      case 'pending_driver_receipt':
        return 'Pending Driver Receipt';
      case 'driver_received_order':
      case 'picked_up':
        return 'Driver Received Order';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'dropped_at_pickup_point':
        return 'Drop At Pickup Point';
      case 'failed':
        return 'Delivery Failed';
      case 'rescheduled':
        return 'Rescheduled';
      case 'returning_to_store':
        return 'Returning To Store';
      case 'returned_to_store':
        return 'Returned To Store';
    }
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1);
        })
        .join(' ');
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body,
          ),
        ),
      ],
    );
  }
}
