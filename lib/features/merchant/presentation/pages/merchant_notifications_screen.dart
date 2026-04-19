import 'package:flutter/material.dart';
import 'package:wasle/core/utils/app_date_time.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_order_details_screen.dart';
import 'package:wasle/features/orders/data/order_service.dart';

class MerchantNotificationsScreen extends StatefulWidget {
  const MerchantNotificationsScreen({super.key});

  @override
  State<MerchantNotificationsScreen> createState() =>
      _MerchantNotificationsScreenState();
}

class _MerchantNotificationsScreenState
    extends State<MerchantNotificationsScreen> {
  final OrdersService _ordersService = OrdersService();

  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await _ordersService.getOrders();
      final recentOrders = orders.take(15).toList();

      final nested = await Future.wait(
        recentOrders.map((order) => _loadEventsForOrder(order)),
      );

      final notifications = <Map<String, dynamic>>[];
      for (final list in nested) {
        notifications.addAll(list);
      }

      notifications.sort(
        (a, b) =>
            _dateValue(b['created_at']).compareTo(_dateValue(a['created_at'])),
      );

      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadEventsForOrder(
    Map<String, dynamic> order,
  ) async {
    final orderId = _safe(order['id'], fallback: '');
    if (orderId.isEmpty) return [];

    try {
      final events = await _ordersService.getOrderEvents(orderId);

      return events.map((event) {
        return {
          'order': order,
          'event': event,
          'created_at': event['created_at'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _openOrder(Map<String, dynamic> order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantOrderDetailsScreen(initialOrder: order),
      ),
    );
    await _load();
  }

  int _dateValue(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) return 0;
    final dt = DateTime.tryParse(raw);
    return dt?.millisecondsSinceEpoch ?? 0;
  }

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _eventTitle(String raw) {
    switch (raw.toLowerCase()) {
      case 'order_created':
        return 'Order created';
      case 'assigned_to_company':
        return 'Assigned to company';
      case 'assigned_to_driver':
        return 'Assigned to driver';
      case 'picked_up':
        return 'Picked up';
      case 'in_transit':
        return 'In transit';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'customer_not_available':
        return 'Customer not available';
      case 'returning':
      case 'returning_to_store':
        return 'Returning to store';
      case 'returned_to_store':
        return 'Returned to store';
      default:
        return raw
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ');
    }
  }

  String _formatDate(dynamic value) {
    return AppDateTime.format(value);
  }

  IconData _eventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'order_created':
        return Icons.add_box_outlined;
      case 'assigned_to_company':
      case 'assigned_to_driver':
        return Icons.assignment_ind_outlined;
      case 'picked_up':
        return Icons.inventory_2_outlined;
      case 'in_transit':
        return Icons.local_shipping_outlined;
      case 'delivered':
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
      case 'customer_not_available':
        return Icons.warning_amber_outlined;
      case 'returning':
      case 'returning_to_store':
      case 'returned_to_store':
        return Icons.undo_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _eventColor(String type) {
    switch (type.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return _W.green;
      case 'cancelled':
      case 'customer_not_available':
        return _W.red;
      case 'returning':
      case 'returning_to_store':
      case 'returned_to_store':
        return _W.amber;
      default:
        return _W.blue;
    }
  }

  Color _eventBg(String type) {
    switch (type.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return _W.greenLt;
      case 'cancelled':
      case 'customer_not_available':
        return _W.redLt;
      case 'returning':
      case 'returning_to_store':
      case 'returned_to_store':
        return _W.amberLt;
      default:
        return _W.blueLt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _W.bg,
      appBar: AppBar(
        backgroundColor: _W.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Notifications', style: _t(18, FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const _EmptyNotificationsState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  14,
                  8,
                  14,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: _notifications.length,
                itemBuilder: (_, i) {
                  final item = _notifications[i];
                  final order = Map<String, dynamic>.from(item['order'] as Map);
                  final event = Map<String, dynamic>.from(item['event'] as Map);

                  final eventType = _safe(
                    event['event_type'],
                    fallback: 'event',
                  );
                  final title = _eventTitle(eventType);
                  final note = _safe(event['note'], fallback: '');
                  final tracking = _safe(order['tracking_code']);
                  final customer = _safe(
                    order['customer_name'],
                    fallback: 'Customer',
                  );
                  final createdAt = _formatDate(event['created_at']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationCard(
                      icon: _eventIcon(eventType),
                      iconColor: _eventColor(eventType),
                      iconBg: _eventBg(eventType),
                      title: title,
                      subtitle: note.isEmpty
                          ? '$customer • $tracking'
                          : '$customer • $tracking\n$note',
                      createdAt: createdAt,
                      onTap: () => _openOrder(order),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _W {
  _W._();

  static const bg = Color(0xFFF4F7FF);
  static const white = Color(0xFFFFFFFF);
  static const blue = Color(0xFF1A56DB);
  static const blueLt = Color(0xFFEBF0FD);
  static const navy = Color(0xFF0B1D3F);
  static const gray = Color(0xFF6B7A99);
  static const border = Color(0xFFDDE5F7);
  static const green = Color(0xFF0BA360);
  static const greenLt = Color(0xFFE6F7EF);
  static const red = Color(0xFFE53054);
  static const redLt = Color(0xFFFDEAED);
  static const amber = Color(0xFFD4800A);
  static const amberLt = Color(0xFFFEF4E2);
  static const slate = Color(0xFF94A3B8);
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

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String createdAt;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _W.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _W.border, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(13.5, FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: _t(
                        12.2,
                        FontWeight.w500,
                        color: _W.gray,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      createdAt,
                      style: _t(11.5, FontWeight.w600, color: _W.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _W.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _W.border, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _W.blueLt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: _W.blue,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text('No notifications yet', style: _t(18, FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'Order activity updates will appear here.',
                style: _t(13, FontWeight.w500, color: _W.gray, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
