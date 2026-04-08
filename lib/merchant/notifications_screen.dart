import 'package:flutter/material.dart';

import 'models/merchant_notification_model.dart';
import 'order_details_screen.dart';
import 'services/order_service.dart';

class _W {
  _W._();
  static const bg = Color(0xFFF4F7FF);
  static const white = Color(0xFFFFFFFF);
  static const navy = Color(0xFF0B1D3F);
  static const blue = Color(0xFF1A56DB);
  static const blueLt = Color(0xFFEBF0FD);
  static const green = Color(0xFF0BA360);
  static const greenLt = Color(0xFFE6F7EF);
  static const red = Color(0xFFE53054);
  static const redLt = Color(0xFFFFEEF2);
  static const amber = Color(0xFFD4800A);
  static const amberLt = Color(0xFFFEF4E2);
  static const border = Color(0xFFDDE5F7);
  static const slate = Color(0xFF6B7A99);
}

TextStyle _t(
  double size,
  FontWeight weight, {
  Color color = _W.navy,
  double? height,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}


String _statusLabel(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'created':
      return 'Created';
    case 'assigned':
      return 'Assigned';
    case 'in_transit':
      return 'In transit';
    case 'delivered':
      return 'Delivered';
    case 'failed':
      return 'Failed';
    case 'cancelled':
      return 'Cancelled';
    case 'returning':
    case 'returning_to_store':
      return 'Returning';
    case 'returned_to_store':
      return 'Returned';
    default:
      return (raw ?? '').trim();
  }
}

class MerchantNotificationsScreen extends StatefulWidget {
  const MerchantNotificationsScreen({super.key});

  @override
  State<MerchantNotificationsScreen> createState() =>
      _MerchantNotificationsScreenState();
}

class _MerchantNotificationsScreenState
    extends State<MerchantNotificationsScreen> {
  late Future<List<MerchantNotificationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = orderService.loadRecentNotifications();
  }

  Future<void> _reload() async {
    final next = orderService.loadRecentNotifications();
    setState(() => _future = next);
    await next;
  }

  Future<void> _openOrder(MerchantNotificationModel item) async {
    final order = await orderService.getOrderWithTimeline(item.orderId);
    if (!mounted) return;

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this order right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: order),
      ),
    );

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _W.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _W.bg,
        surfaceTintColor: _W.bg,
        foregroundColor: _W.navy,
        title: Text(
          'Notifications',
          style: _t(18, FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<MerchantNotificationModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                color: _W.blue,
              ),
            );
          }

          final items = snapshot.data ?? const [];

          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _W.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _W.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: _W.blueLt,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none,
                            color: _W.blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: _t(18, FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Recent order updates will appear here so the merchant can follow assignments, delivery progress, failures, and returns.',
                          style: _t(
                            14,
                            FontWeight.w500,
                            color: _W.slate,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationCard(
                  item: item,
                  onTap: () => _openOrder(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final MerchantNotificationModel item;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(item.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _W.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _W.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.$2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconForEvent(item.eventType),
                  color: colors.$1,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: _t(15, FontWeight.w800),
                          ),
                        ),
                        if (item.createdAt != null)
                          Text(
                            item.createdAt!,
                            style: _t(
                              12,
                              FontWeight.w600,
                              color: _W.slate,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: _t(
                        13,
                        FontWeight.w500,
                        color: _W.slate,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniChip(
                          icon: Icons.qr_code_2,
                          label: item.trackingCode,
                          color: _W.blue,
                          bg: _W.blueLt,
                        ),
                        if ((item.status ?? '').isNotEmpty)
                          _MiniChip(
                            icon: Icons.local_shipping_outlined,
                            label: _statusLabel(item.status),
                            color: colors.$1,
                            bg: colors.$2,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: _W.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: _t(12, FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

(Color, Color) _statusColors(String? status) {
  switch ((status ?? '').trim().toLowerCase()) {
    case 'delivered':
      return (_W.green, _W.greenLt);
    case 'failed':
    case 'cancelled':
      return (_W.red, _W.redLt);
    case 'returning':
    case 'returned_to_store':
      return (_W.amber, _W.amberLt);
    default:
      return (_W.blue, _W.blueLt);
  }
}

IconData _iconForEvent(String raw) {
  switch (raw) {
    case 'assigned_to_company':
    case 'assigned_to_driver':
      return Icons.assignment_turned_in_outlined;
    case 'picked_up':
      return Icons.inventory_2_outlined;
    case 'in_transit':
      return Icons.local_shipping_outlined;
    case 'delivered':
      return Icons.check_circle_outline;
    case 'cancelled':
      return Icons.cancel_outlined;
    case 'delivery_failed':
    case 'failed':
      return Icons.error_outline;
    case 'dropped_at_pickup_point':
      return Icons.storefront_outlined;
    case 'returning_to_store':
    case 'returned_to_store':
      return Icons.assignment_return_outlined;
    default:
      return Icons.notifications_none;
  }
}
