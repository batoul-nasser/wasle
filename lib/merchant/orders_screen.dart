// lib/merchant/orders_screen.dart

import 'package:flutter/material.dart';
import 'models/order_model.dart';
import 'services/order_service.dart';
import 'order_details_screen.dart';

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
  static const slateLt = Color(0xFFF1F4FC);
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

Color _statusFg(String s) {
  if (s == 'delivered') return _W.green;
  if (s == 'failed') return _W.red;
  if (s == 'assigned' || s == 'in_transit') return _W.blue;
  if (s == 'created') return _W.amber;
  return _W.gray;
}

Color _statusBg(String s) {
  if (s == 'delivered') return _W.greenLt;
  if (s == 'failed') return _W.redLt;
  if (s == 'assigned' || s == 'in_transit') return _W.blueLt;
  if (s == 'created') return _W.amberLt;
  return _W.slateLt;
}

String _statusLabel(String s) {
  switch (s) {
    case 'created':
      return 'Created';
    case 'assigned':
      return 'Assigned';
    case 'in_transit':
      return 'In Transit';
    case 'delivered':
      return 'Delivered';
    case 'failed':
      return 'Failed';
    default:
      return s;
  }
}

const List<String> _kFilters = [
  'All',
  'created',
  'assigned',
  'in_transit',
  'delivered',
  'failed',
];

class OrdersScreen extends StatefulWidget {
  final String initialFilter;

  const OrdersScreen({
    super.key,
    this.initialFilter = 'All',
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late String _selectedStatus;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedStatus =
        _kFilters.contains(widget.initialFilter) ? widget.initialFilter : 'All';
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialFilter != widget.initialFilter &&
        _kFilters.contains(widget.initialFilter)) {
      _selectedStatus = widget.initialFilter;
    }
  }

  List<OrderModel> _filter(List<OrderModel> all) {
    return all.where((o) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          o.customerName.toLowerCase().contains(q) ||
          o.trackingCode.toLowerCase().contains(q);

      final matchStatus =
          _selectedStatus == 'All' || o.status == _selectedStatus;

      return matchSearch && matchStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<OrderModel>>(
      valueListenable: orderService,
      builder: (context, orders, _) {
        final filtered = _filter(orders);

        return Container(
          color: _W.bg,
          child: Column(
            children: [
              _TopNav(
                totalCount: orders.length,
                selectedStatus: _selectedStatus,
                filteredCount: filtered.length,
              ),
              _Toolbar(
                search: _search,
                selectedStatus: _selectedStatus,
                onSearchChanged: (v) => setState(() => _search = v),
                onStatusChanged: (v) => setState(() => _selectedStatus = v),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        selectedStatus: _selectedStatus,
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          4,
                          14,
                          28 + MediaQuery.of(context).padding.bottom,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _OrderCard(order: filtered[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopNav extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final String selectedStatus;

  const _TopNav({
    required this.totalCount,
    required this.filteredCount,
    required this.selectedStatus,
  });

  @override
  Widget build(BuildContext context) {
    final label = selectedStatus == 'All'
        ? '$totalCount orders'
        : '$filteredCount ${_statusLabel(selectedStatus).toLowerCase()}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _W.blueLt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _W.border, width: 1.5),
            ),
            child: Text(
              label,
              style: _t(13, FontWeight.w800, color: _W.blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final String search;
  final String selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;

  const _Toolbar({
    required this.search,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _W.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _W.border, width: 1.5),
            ),
            child: TextField(
              style: _t(14, FontWeight.w500),
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or tracking code…',
                hintStyle: _t(14, FontWeight.w400, color: _W.slate),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: _W.slate,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) {
                final f = _kFilters[i];
                final active = selectedStatus == f;
                final fg = (f == 'All' && active)
                    ? _W.blue
                    : (active ? _statusFg(f) : _W.gray);
                final bg = (f == 'All' && active)
                    ? _W.blueLt
                    : (active ? _statusBg(f) : _W.white);
                final bc = (f == 'All' && active)
                    ? _W.blue
                    : (active ? _statusFg(f) : _W.border);

                return GestureDetector(
                  onTap: () => onStatusChanged(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: bc, width: 1.5),
                    ),
                    child: Text(
                      f == 'All' ? 'All' : _statusLabel(f),
                      style: _t(12.5, FontWeight.w700, color: fg),
                    ),
                  ),
                );
              },
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.trackingCode,
                        style: _t(14, FontWeight.w900),
                      ),
                    ),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _W.blueLt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: _W.blue,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: _t(13.5, FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.customerPhone,
                            style: _t(
                              12,
                              FontWeight.w500,
                              color: _W.gray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: _W.slate,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        order.address,
                        style: _t(
                          12.5,
                          FontWeight.w500,
                          color: _W.gray,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: _W.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      _FooterChip(
                        icon: Icons.storefront_outlined,
                        label: 'Pickup',
                        value: order.pickupMethod,
                      ),
                      const SizedBox(width: 8),
                      _FooterChip(
                        icon: Icons.attach_money,
                        label: 'COD',
                        value: order.codAmount > 0
                            ? '\$${order.codAmount.toStringAsFixed(0)}'
                            : 'Paid online',
                        valueColor: order.codAmount > 0 ? _W.blue : _W.green,
                      ),
                      if (order.status == 'failed') ...[
                        const SizedBox(width: 8),
                        _FooterChip(
                          icon: Icons.warning_amber_outlined,
                          label: 'Issue',
                          value: order.failedReason ?? 'Failed order',
                          valueColor: _W.red,
                          bgColor: _W.redLt,
                          borderColor: _W.red,
                        ),
                      ],
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

class _FooterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? bgColor;
  final Color? borderColor;

  const _FooterChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.bgColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor ?? _W.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor?.withOpacity(0.25) ?? _W.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: valueColor ?? _W.slate),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: _t(10, FontWeight.w600, color: _W.gray),
              ),
              Text(
                value,
                style: _t(
                  11.5,
                  FontWeight.w700,
                  color: valueColor ?? _W.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final fg = _statusFg(status);
    final bg = _statusBg(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25), width: 1),
      ),
      child: Text(
        _statusLabel(status),
        style: _t(11, FontWeight.w800, color: fg),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String selectedStatus;

  const _EmptyState({
    required this.selectedStatus,
  });

  @override
  Widget build(BuildContext context) {
    final title = selectedStatus == 'failed'
        ? 'No failed orders'
        : 'No orders found';

    final subtitle = selectedStatus == 'failed'
        ? 'There are no failed orders right now.'
        : 'Try changing the search keyword\nor selecting another status filter.';

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
                  color: selectedStatus == 'failed' ? _W.redLt : _W.blueLt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  selectedStatus == 'failed'
                      ? Icons.warning_amber_outlined
                      : Icons.inventory_2_outlined,
                  color: selectedStatus == 'failed' ? _W.red : _W.blue,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: _t(18, FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: _t(
                  13,
                  FontWeight.w500,
                  color: _W.gray,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}