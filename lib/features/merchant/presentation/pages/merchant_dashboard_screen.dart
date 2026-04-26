import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/orders/data/order_service.dart';

class MerchantDashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenCreate;
  final VoidCallback? onOpenOrders;

  const MerchantDashboardScreen({
    super.key,
    this.onOpenCreate,
    this.onOpenOrders,
  });

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  final AuthService _authService = AuthService();
  final OrdersService _ordersService = OrdersService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _authService.getCurrentProfile(),
        _ordersService.getOrders(),
      ]);

      if (!mounted) return;

      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _orders = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _normalizedStatus(dynamic value) {
    final status = _safe(value, fallback: 'created').toLowerCase();
    if (status == 'pending') return 'created';
    if (status == 'completed') return 'delivered';
    if (status == 'assigned_to_company' || status == 'assigned_to_driver') {
      return 'assigned';
    }
    return status;
  }

  bool _isDelivered(Map<String, dynamic> order) {
    final status = _normalizedStatus(order['status']);
    return status == 'delivered';
  }

  bool _isIssue(Map<String, dynamic> order) {
    final status = _normalizedStatus(order['status']);
    return status == 'failed' ||
        status == 'cancelled' ||
        status == 'customer_not_available' ||
        status == 'returning' ||
        status == 'returning_to_store' ||
        status == 'returned_to_store';
  }

  bool _isActive(Map<String, dynamic> order) {
    return !_isDelivered(order) && !_isIssue(order);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'created':
        return 'Created';
      case 'assigned':
        return 'Assigned';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
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
      case 'customer_not_available':
        return 'Customer Not Available';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status) {
    if (status == 'delivered') return _W.green;
    if (status == 'failed' ||
        status == 'cancelled' ||
        status == 'customer_not_available') {
      return _W.red;
    }
    if (status == 'returning' ||
        status == 'returning_to_store' ||
        status == 'returned_to_store') {
      return _W.amber;
    }
    return _W.blue;
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _safe(_profile?['full_name'], fallback: 'Merchant');
    final totalOrders = _orders.length;
    final activeOrders = _orders.where(_isActive).length;
    final deliveredOrders = _orders.where(_isDelivered).length;
    final issueOrders = _orders.where(_isIssue).length;
    final recentOrders = _orders.take(4).toList();

    return Scaffold(
      backgroundColor: _W.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  const _TopBar(),
                  const SizedBox(height: 4),
                  if (_error != null) ...[
                    _InfoBox(
                      icon: Icons.error_outline,
                      text: _error ?? 'Unable to load merchant dashboard.',
                      color: _W.red,
                      background: _W.redLt,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _HeroCard(
                    merchantName: fullName,
                    totalOrders: totalOrders,
                    activeOrders: activeOrders,
                    issueOrders: issueOrders,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useStackedActions =
                          constraints.maxWidth.isFinite &&
                          constraints.maxWidth < 360;
                      final cardWidth = constraints.maxWidth.isFinite
                          ? (constraints.maxWidth - 10) / 2
                          : 160.0;
                      final createAction = _ActionCard(
                        icon: Icons.add_box_outlined,
                        title: 'Create Order',
                        subtitle: 'Start a paid delivery',
                        color: _W.blue,
                        background: _W.blueLt,
                        onTap: widget.onOpenCreate,
                      );
                      final ordersAction = _ActionCard(
                        icon: Icons.receipt_long_outlined,
                        title: 'View Orders',
                        subtitle: 'Search and filter',
                        color: _W.green,
                        background: _W.greenLt,
                        onTap: widget.onOpenOrders,
                      );

                      if (useStackedActions) {
                        return Column(
                          children: [
                            createAction,
                            const SizedBox(height: 10),
                            ordersAction,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          SizedBox(width: cardWidth, child: createAction),
                          const SizedBox(width: 10),
                          SizedBox(width: cardWidth, child: ordersAction),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _StatsGrid(
                    totalOrders: totalOrders,
                    activeOrders: activeOrders,
                    deliveredOrders: deliveredOrders,
                    issueOrders: issueOrders,
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    icon: Icons.history_outlined,
                    iconColor: _W.slate,
                    iconBg: _W.slateLt,
                    title: 'Recent Orders',
                    subtitle: 'Latest merchant activity',
                    child: recentOrders.isEmpty
                        ? const _EmptyRecentOrders()
                        : Column(
                            children: [
                              for (final order in recentOrders)
                                _RecentOrderTile(
                                  order: order,
                                  statusLabel: _statusLabel(
                                    _normalizedStatus(order['status']),
                                  ),
                                  statusColor: _statusColor(
                                    _normalizedStatus(order['status']),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
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
  static const blueDark = Color(0xFF1044C4);
  static const blueLt = Color(0xFFEBF0FD);
  static const navy = Color(0xFF0B1D3F);
  static const gray = Color(0xFF6B7A99);
  static const border = Color(0xFFDDE5F7);
  static const green = Color(0xFF0BA360);
  static const greenLt = Color(0xFFE6F7EF);
  static const red = Color(0xFFE53054);
  static const redLt = Color(0xFFFDEAED);
  static const amber = Color(0xFFD4800A);
  static const slate = Color(0xFF94A3B8);
  static const slateLt = Color(0xFFF1F4FC);
  static const white13 = Color(0x22FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white70 = Color(0xB3FFFFFF);
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
    letterSpacing: 0,
  );
}

BoxDecoration _cardDecor({double radius = 8}) {
  return BoxDecoration(
    color: _W.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _W.border, width: 1.5),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _W.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  style: _t(22, FontWeight.w900),
                  children: const [
                    TextSpan(text: 'wa'),
                    TextSpan(
                      text: 'sle',
                      style: TextStyle(color: _W.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _W.blueLt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _W.border, width: 1.5),
            ),
            child: Text(
              'Merchant',
              style: _t(12.5, FontWeight.w800, color: _W.blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String merchantName;
  final int totalOrders;
  final int activeOrders;
  final int issueOrders;

  const _HeroCard({
    required this.merchantName,
    required this.totalOrders,
    required this.activeOrders,
    required this.issueOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _W.blueDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merchant Dashboard',
            style: _t(22, FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            'Welcome, $merchantName. Manage paid orders and delivery activity.',
            style: _t(13, FontWeight.w500, color: _W.white70, height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(
                icon: Icons.inventory_2_outlined,
                label: '$totalOrders total',
              ),
              _HeroChip(
                icon: Icons.local_shipping_outlined,
                label: '$activeOrders active',
              ),
              _HeroChip(
                icon: Icons.error_outline,
                label: '$issueOrders issues',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: _W.white13,
        border: Border.all(color: _W.white20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(label, style: _t(12, FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 98),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.22),
              width: 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 18),
              Text(title, style: _t(13.5, FontWeight.w800, color: color)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: _t(12, FontWeight.w600, color: color, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int totalOrders;
  final int activeOrders;
  final int deliveredOrders;
  final int issueOrders;

  const _StatsGrid({
    required this.totalOrders,
    required this.activeOrders,
    required this.deliveredOrders,
    required this.issueOrders,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.36,
      children: [
        _StatCard(
          title: 'Total Orders',
          value: '$totalOrders',
          icon: Icons.inventory_2_outlined,
          color: _W.blue,
        ),
        _StatCard(
          title: 'Active',
          value: '$activeOrders',
          icon: Icons.route_outlined,
          color: _W.amber,
        ),
        _StatCard(
          title: 'Delivered',
          value: '$deliveredOrders',
          icon: Icons.check_circle_outline,
          color: _W.green,
        ),
        _StatCard(
          title: 'Issues',
          value: '$issueOrders',
          icon: Icons.warning_amber_outlined,
          color: _W.red,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 14),
          Text(value, style: _t(24, FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(title, style: _t(12, FontWeight.w600, color: _W.gray)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final textWidth = constraints.maxWidth.isFinite
                  ? (constraints.maxWidth > 46
                        ? constraints.maxWidth - 46
                        : 0.0)
                  : 220.0;
              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 17, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: textWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(15, FontWeight.w800),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _t(12, FontWeight.w500, color: _W.gray),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _W.border),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final String statusLabel;
  final Color statusColor;

  const _RecentOrderTile({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
  });

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _W.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _W.border, width: 1.2),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final statusWidth = constraints.maxWidth.isFinite
                ? (constraints.maxWidth < 280 ? 72.0 : 96.0)
                : 96.0;
            final detailsWidth = constraints.maxWidth.isFinite
                ? (constraints.maxWidth - 38 - 10 - 8 - statusWidth).clamp(
                    0.0,
                    double.infinity,
                  )
                : 180.0;

            return Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: statusColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: detailsWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _safe(order['customer_name'], fallback: 'Customer'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(13, FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _safe(order['tracking_code']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(11.5, FontWeight.w600, color: _W.gray),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: statusWidth,
                  child: Text(
                    statusLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: _t(11.5, FontWeight.w800, color: statusColor),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyRecentOrders extends StatelessWidget {
  const _EmptyRecentOrders();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Created orders will appear here.',
        style: _t(13, FontWeight.w500, color: _W.gray),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  const _InfoBox({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1.3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textWidth = constraints.maxWidth.isFinite
              ? (constraints.maxWidth > 28 ? constraints.maxWidth - 28 : 0.0)
              : 220.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              SizedBox(
                width: textWidth,
                child: Text(
                  text,
                  style: _t(12.5, FontWeight.w600, color: color, height: 1.4),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
