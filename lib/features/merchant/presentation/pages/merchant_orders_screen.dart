import 'package:flutter/material.dart';
import 'package:wasle/core/utils/app_date_time.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_order_details_screen.dart';
import 'package:wasle/features/orders/data/order_service.dart';

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

const List<String> _kFilters = [
  'All',
  'created',
  'assigned',
  'in_transit',
  'delivered',
  'failed',
  'cancelled',
  'returning',
  'returned_to_store',
  'exceptions',
];

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  final OrdersService _ordersService = OrdersService();

  bool _loading = true;
  String _selectedStatus = 'All';
  String _search = '';
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _ordersService.getOrders();
      if (!mounted) return;

      setState(() {
        _orders = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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

  List<Map<String, dynamic>> _filtered() {
    return _orders.where((o) {
      final q = _search.toLowerCase();
      final customer = _safe(o['customer_name']).toLowerCase();
      final tracking = _safe(o['tracking_code']).toLowerCase();
      final phone = _safe(o['customer_phone']).toLowerCase();
      final status = _normalizedStatus(o['status']);

      final matchSearch =
          q.isEmpty ||
          customer.contains(q) ||
          tracking.contains(q) ||
          phone.contains(q);

      const exceptionStatuses = {
        'failed',
        'cancelled',
        'returning',
        'returned_to_store',
        'customer_not_available',
      };

      final matchStatus = _selectedStatus == 'All'
          ? true
          : _selectedStatus == 'exceptions'
          ? exceptionStatuses.contains(status)
          : _matchesSelectedFilter(status, _selectedStatus);

      return matchSearch && matchStatus;
    }).toList();
  }

  bool _matchesSelectedFilter(String status, String selected) {
    if (status == selected) return true;

    if (selected == 'assigned') {
      return status == 'assigned' ||
          status == 'assigned_to_company' ||
          status == 'assigned_to_driver' ||
          status == 'picked_up';
    }

    if (selected == 'in_transit') {
      return status == 'in_transit';
    }

    if (selected == 'delivered') {
      return status == 'delivered' || status == 'completed';
    }

    return false;
  }

  String _normalizedStatus(dynamic value) {
    final s = _safe(value).toLowerCase();

    if (s == 'pending') return 'created';
    if (s == 'completed') return 'delivered';
    if (s == 'assigned_to_company' || s == 'assigned_to_driver') {
      return 'assigned';
    }

    return s;
  }

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatDate(dynamic value) {
    return AppDateTime.format(value, fallback: '-');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    return Scaffold(
      backgroundColor: _W.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _TopNav(
                  totalCount: _orders.length,
                  selectedStatus: _selectedStatus,
                  filteredCount: filtered.length,
                ),
                _Toolbar(
                  selectedStatus: _selectedStatus,
                  onSearchChanged: (v) => setState(() => _search = v),
                  onStatusChanged: (v) => setState(() => _selectedStatus = v),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? _EmptyState(selectedStatus: _selectedStatus)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              14,
                              4,
                              14,
                              28 + MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _OrderCard(
                              order: filtered[i],
                              formattedDate: _formatDate(
                                filtered[i]['created_at'],
                              ),
                              onTap: () => _openOrder(filtered[i]),
                            ),
                          ),
                        ),
                ),
              ],
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
  final normalized = s.toLowerCase();

  if (normalized == 'delivered' || normalized == 'completed') return _W.green;
  if (normalized == 'failed' ||
      normalized == 'cancelled' ||
      normalized == 'customer_not_available') {
    return _W.red;
  }
  if (normalized == 'returning' || normalized == 'returned_to_store') {
    return _W.amber;
  }
  if (normalized == 'assigned' ||
      normalized == 'assigned_to_company' ||
      normalized == 'assigned_to_driver' ||
      normalized == 'picked_up' ||
      normalized == 'in_transit') {
    return _W.blue;
  }
  if (normalized == 'created' || normalized == 'pending') return _W.amber;
  return _W.gray;
}

Color _statusBg(String s) {
  final normalized = s.toLowerCase();

  if (normalized == 'delivered' || normalized == 'completed') return _W.greenLt;
  if (normalized == 'failed' ||
      normalized == 'cancelled' ||
      normalized == 'customer_not_available') {
    return _W.redLt;
  }
  if (normalized == 'returning' || normalized == 'returned_to_store') {
    return _W.amberLt;
  }
  if (normalized == 'assigned' ||
      normalized == 'assigned_to_company' ||
      normalized == 'assigned_to_driver' ||
      normalized == 'picked_up' ||
      normalized == 'in_transit') {
    return _W.blueLt;
  }
  if (normalized == 'created' || normalized == 'pending') return _W.amberLt;
  return _W.slateLt;
}

String _statusLabel(String s) {
  switch (s.toLowerCase()) {
    case 'created':
      return 'Created';
    case 'pending':
      return 'Pending';
    case 'assigned':
    case 'assigned_to_company':
    case 'assigned_to_driver':
      return 'Assigned';
    case 'picked_up':
      return 'Picked Up';
    case 'in_transit':
      return 'In Transit';
    case 'delivered':
    case 'completed':
      return 'Delivered';
    case 'failed':
      return 'Failed';
    case 'cancelled':
      return 'Cancelled';
    case 'returning':
      return 'Returning';
    case 'returned_to_store':
      return 'Returned';
    case 'exceptions':
      return 'Issues';
    case 'customer_not_available':
      return 'Customer Not Available';
    default:
      return s;
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
            child: Text(label, style: _t(13, FontWeight.w800, color: _W.blue)),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;

  const _Toolbar({
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
                hintText: 'Search by name, phone, or tracking code...',
                hintStyle: _t(14, FontWeight.w400, color: _W.slate),
                prefixIcon: const Icon(Icons.search, size: 20, color: _W.slate),
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
              separatorBuilder: (_, _) => const SizedBox(width: 7),
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
  final Map<String, dynamic> order;
  final String formattedDate;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.formattedDate,
    required this.onTap,
  });

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  bool get _hasPayment {
    return order['_payment'] != null ||
        _safe(order['payment_method'], fallback: '').isNotEmpty ||
        _safe(order['payment_amount'], fallback: '').isNotEmpty;
  }

  String get _paymentMethodLabel {
    final method = _safe(order['payment_method'], fallback: '').toLowerCase();
    switch (method) {
      case 'cash_at_pickup':
      case 'cod':
        return 'Cash';
      case 'whish_online':
        return 'Whish';
      case 'card':
        return 'Card';
      default:
        return method.isEmpty ? 'Payment' : method.replaceAll('_', ' ');
    }
  }

  String get _paymentAmountLabel {
    final amount = order['payment_amount'];
    if (amount is num) return '\$${amount.toStringAsFixed(2)}';
    final text = _safe(amount, fallback: '');
    return text.isEmpty ? _paymentMethodLabel : '\$$text';
  }

  Color get _paymentColor {
    final status = _safe(
      order['payment_status'],
      fallback: 'pending',
    ).toLowerCase();
    if (status == 'paid') return _W.green;
    if (status == 'failed' || status == 'refunded') return _W.red;
    return _W.amber;
  }

  @override
  Widget build(BuildContext context) {
    final status = _safe(order['status'], fallback: 'created');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _W.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: _W.blue.withValues(alpha: 0.06),
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
                        _safe(order['tracking_code']),
                        style: _t(14, FontWeight.w900),
                      ),
                    ),
                    _StatusBadge(status: status),
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
                            _safe(order['customer_name'], fallback: 'Customer'),
                            style: _t(13.5, FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _safe(order['customer_phone']),
                            style: _t(12, FontWeight.w500, color: _W.gray),
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
                        _safe(
                          order['customer_address_text'],
                          fallback: 'No address',
                        ),
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
                    border: Border(top: BorderSide(color: _W.border, width: 1)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FooterChip(
                        icon: Icons.route_outlined,
                        label: 'Status',
                        value: _statusLabel(status),
                        valueColor: _statusFg(status),
                        bgColor: _statusBg(status),
                        borderColor: _statusFg(status),
                      ),
                      const SizedBox(width: 8),
                      _FooterChip(
                        icon: Icons.schedule_outlined,
                        label: 'Created',
                        value: formattedDate,
                      ),
                      if (_hasPayment)
                        _FooterChip(
                          icon: Icons.payments_outlined,
                          label: _paymentMethodLabel,
                          value: _paymentAmountLabel,
                          valueColor: _paymentColor,
                          bgColor: _paymentColor.withValues(alpha: 0.10),
                          borderColor: _paymentColor,
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
          color: borderColor?.withValues(alpha: 0.25) ?? _W.border,
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
              Text(label, style: _t(10, FontWeight.w600, color: _W.gray)),
              Text(
                value,
                style: _t(11.5, FontWeight.w700, color: valueColor ?? _W.navy),
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
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
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

  const _EmptyState({required this.selectedStatus});

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
