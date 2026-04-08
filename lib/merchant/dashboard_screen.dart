// lib/merchant/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'models/order_model.dart';
import 'services/order_service.dart';
import 'order_details_screen.dart';
import 'notifications_screen.dart';
import 'package:wasle/ui/auth/auth_controller.dart';

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
  static const amberLt = Color(0xFFFEF4E2);
  static const slate = Color(0xFF94A3B8);
  static const statusFallback = Color(0xFFF1F4FC);
  static const white60 = Color(0x99FFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const white13 = Color(0x22FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white67 = Color(0xAAFFFFFF);
  static const white07 = Color(0x12FFFFFF);
  static const white03 = Color(0x08FFFFFF);
}

TextStyle _t(
  double size,
  FontWeight w, {
  Color color = _W.navy,
  double? height,
  double? spacing,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
}

BoxDecoration _cardDecor({double radius = 20}) {
  return BoxDecoration(
    color: _W.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _W.border, width: 1.5),
  );
}

class DashboardScreen extends StatelessWidget {
  final VoidCallback onGoToCreate;
  final VoidCallback onGoToOrders;
  final VoidCallback onGoToExceptions;

  const DashboardScreen({
    super.key,
    required this.onGoToCreate,
    required this.onGoToOrders,
    required this.onGoToExceptions,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: authController.getMyProfile(),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final merchantName =
            profile?["full_name"]?.toString().trim().isNotEmpty == true
                ? profile!["full_name"].toString().trim()
                : "Merchant Account";
        final merchantSubtitle =
            authController.currentUser?.email?.trim().isNotEmpty == true
                ? authController.currentUser!.email!.trim()
                : "Merchant account overview";

        return ValueListenableBuilder<List<OrderModel>>(
          valueListenable: orderService,
          builder: (context, orders, _) {
            const exceptionStatuses = {'failed', 'cancelled', 'returning', 'returned_to_store'};
            final active = orders
                .where((o) => o.status != 'delivered' && !exceptionStatuses.contains(o.status))
                .length;
            final delivered = orders.where((o) => o.status == 'delivered').length;
            final failed = orders.where((o) => exceptionStatuses.contains(o.status)).length;

            double codTotal = 0;
            int codCount = 0;
            for (final o in orders) {
              if (o.status != 'delivered' && o.codAmount > 0) {
                codTotal += o.codAmount;
                codCount++;
              }
            }

            return Container(
              color: _W.bg,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  const _TopNav(),
                  const SizedBox(height: 4),
                  _HeroBanner(
                    total: orders.length,
                    active: active,
                    issues: failed,
                    merchantName: merchantName,
                    merchantSubtitle: merchantSubtitle,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_shipping_outlined,
                          iconColor: _W.blue,
                          iconBg: _W.blueLt,
                          value: '$active',
                          label: 'Active',
                          sublabel: 'In transit',
                          valueColor: _W.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle_outline,
                          iconColor: _W.green,
                          iconBg: _W.greenLt,
                          value: '$delivered',
                          label: 'Delivered',
                          sublabel: 'Completed',
                          valueColor: _W.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _WideStatCard(
                    icon: Icons.error_outline,
                    iconColor: _W.red,
                    iconBg: _W.redLt,
                    value: '$failed',
                    label: 'Failed / Issues',
                    sublabel: 'Needs your attention now',
                    valueColor: _W.red,
                  ),
                  const SizedBox(height: 10),
                  if (codTotal > 0) ...[
                    _CodCard(amount: codTotal, orderCount: codCount),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 10),
                  const _SectionTitle(text: 'Quick Actions'),
                  const SizedBox(height: 12),
                  _ActionsGrid(
                    onGoToCreate: onGoToCreate,
                    onGoToOrders: onGoToOrders,
                    onGoToExceptions: onGoToExceptions,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionTitle(text: 'Recent Orders'),
                      GestureDetector(
                        onTap: onGoToOrders,
                        child: Text(
                          'View all →',
                          style: _t(13, FontWeight.w700, color: _W.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (orders.isEmpty)
                    _EmptyOrdersCard(onGoToCreate: onGoToCreate)
                  else
                    ...orders.take(3).map((o) => _OrderCard(order: o)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav();

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _W.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _W.blue,
              borderRadius: BorderRadius.circular(10),
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
              style: _t(22, FontWeight.w900, spacing: -0.5),
              children: const [
                TextSpan(text: 'wa'),
                TextSpan(
                  text: 'sle',
                  style: TextStyle(color: _W.blue),
                ),
              ],
            ),
          ),
          const Spacer(),
          _NavIconBtn(
            icon: Icons.notifications_outlined,
            hasDot: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MerchantNotificationsScreen(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _NavIconBtn(
            icon: Icons.person_outline,
            onTap: () => _showInfo(
              context,
              'Use the Profile tab below to manage your account.',
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIconBtn extends StatelessWidget {
  final IconData icon;
  final bool hasDot;
  final VoidCallback? onTap;

  const _NavIconBtn({
    required this.icon,
    this.hasDot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: _cardDecor(radius: 12),
              child: Icon(icon, size: 18, color: _W.navy),
            ),
          ),
        ),
        if (hasDot)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _W.red,
                shape: BoxShape.circle,
                border: Border.all(color: _W.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final int total;
  final int active;
  final int issues;
  final String merchantName;
  final String merchantSubtitle;

  const _HeroBanner({
    required this.total,
    required this.active,
    required this.issues,
    required this.merchantName,
    required this.merchantSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_W.blueDark, _W.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: _W.white07,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: 30,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: _W.white03,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MERCHANT PORTAL',
                style: _t(
                  10,
                  FontWeight.w700,
                  color: _W.white60,
                  spacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome back',
                style: _t(22, FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 3),
              Text(
                merchantName,
                style: _t(16, FontWeight.w800, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                merchantSubtitle,
                style: _t(13, FontWeight.w500, color: _W.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(
                    icon: Icons.inventory_2_outlined,
                    label: '$total orders total',
                  ),
                  _HeroChip(
                    icon: Icons.local_shipping_outlined,
                    label: '$active active now',
                  ),
                  _HeroChip(
                    icon: Icons.error_outline,
                    label: '$issues issues',
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _W.white13,
        border: Border.all(color: _W.white20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: _t(12, FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color valueColor;
  final String value;
  final String label;
  final String sublabel;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: _t(30, FontWeight.w900, color: valueColor),
          ),
          const SizedBox(height: 3),
          Text(label, style: _t(13, FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: _t(11, FontWeight.w600, color: _W.gray),
          ),
        ],
      ),
    );
  }
}

class _WideStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color valueColor;
  final String value;
  final String label;
  final String sublabel;

  const _WideStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: _cardDecor(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: _t(30, FontWeight.w900, color: valueColor),
              ),
              const SizedBox(height: 2),
              Text(label, style: _t(14, FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: _t(11.5, FontWeight.w500, color: _W.gray),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodCard extends StatelessWidget {
  final double amount;
  final int orderCount;

  const _CodCard({required this.amount, required this.orderCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_W.blueDark, _W.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _W.white13,
              borderRadius: BorderRadius.all(Radius.circular(13)),
            ),
            child: const Icon(
              Icons.credit_card_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'COD PENDING',
                  style: _t(
                    10,
                    FontWeight.w700,
                    color: _W.white67,
                    spacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: _t(22, FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _W.white13,
              border: Border.all(color: _W.white20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$orderCount orders',
              style: _t(12, FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _t(17, FontWeight.w900));
  }
}

class _ActionsGrid extends StatelessWidget {
  final VoidCallback onGoToCreate;
  final VoidCallback onGoToOrders;
  final VoidCallback onGoToExceptions;

  const _ActionsGrid({
    required this.onGoToCreate,
    required this.onGoToOrders,
    required this.onGoToExceptions,
  });

  void _showSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label will be connected soon.'),
        backgroundColor: _W.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'icon': Icons.add_box_outlined,
        'iconColor': _W.blue,
        'iconBg': _W.blueLt,
        'title': 'New Order',
        'subtitle': 'Create a new delivery order',
        'onTap': onGoToCreate,
      },
      {
        'icon': Icons.receipt_long_outlined,
        'iconColor': _W.green,
        'iconBg': _W.greenLt,
        'title': 'All Orders',
        'subtitle': 'Filter by status or date',
        'onTap': onGoToOrders,
      },
      {
        'icon': Icons.location_on_outlined,
        'iconColor': _W.amber,
        'iconBg': _W.amberLt,
        'title': 'Pickup Points',
        'subtitle': 'Pickup points module coming soon',
        'onTap': () => _showSoon(context, 'Pickup Points'),
      },
      {
        'icon': Icons.warning_amber_outlined,
        'iconColor': _W.red,
        'iconBg': _W.redLt,
        'title': 'Exceptions',
        'subtitle': 'Review failed orders only',
        'onTap': onGoToExceptions,
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items
          .map(
            (item) => _ActionTile(
              icon: item['icon'] as IconData,
              iconColor: item['iconColor'] as Color,
              iconBg: item['iconBg'] as Color,
              title: item['title'] as String,
              subtitle: item['subtitle'] as String,
              onTap: item['onTap'] as VoidCallback,
            ),
          )
          .toList(),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
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
        splashColor: iconColor.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _W.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: _t(13, FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  subtitle,
                  style: _t(
                    10.5,
                    FontWeight.w500,
                    color: _W.gray,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOrdersCard extends StatelessWidget {
  final VoidCallback onGoToCreate;

  const _EmptyOrdersCard({required this.onGoToCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecor(),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _W.blueLt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _W.blue,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No orders yet',
            style: _t(15, FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your first order to see it here.',
            style: _t(12.5, FontWeight.w500, color: _W.gray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onGoToCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Order'),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _W.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(order: order),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          splashColor: _W.blue.withOpacity(0.06),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _W.blueLt,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: _W.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              order.trackingCode,
                              style: _t(13.5, FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.customerName,
                        style: _t(12.5, FontWeight.w600, color: _W.gray),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.address,
                        style: _t(12, FontWeight.w500, color: _W.slate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (order.codAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.attach_money,
                                size: 13,
                                color: _W.blue,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'COD \$${order.codAmount.toStringAsFixed(2)}',
                                style: _t(
                                  12,
                                  FontWeight.w700,
                                  color: _W.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color _bg() {
    if (status == 'delivered') return _W.greenLt;
    if (status == 'failed') return _W.redLt;
    if (status == 'assigned' || status == 'in_transit') return _W.blueLt;
    return _W.statusFallback;
  }

  Color _fg() {
    if (status == 'delivered') return _W.green;
    if (status == 'failed') return _W.red;
    if (status == 'assigned' || status == 'in_transit') return _W.blue;
    if (status == 'created') return _W.amber;
    return _W.gray;
  }

  String _label() {
    if (status == 'created') return 'Created';
    if (status == 'assigned') return 'Assigned';
    if (status == 'in_transit') return 'In Transit';
    if (status == 'delivered') return 'Delivered';
    if (status == 'failed') return 'Failed';
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _fg().withOpacity(0.25)),
      ),
      child: Text(
        _label(),
        style: _t(11, FontWeight.w800, color: _fg()),
      ),
    );
  }
}