import 'package:flutter/material.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_order_details_screen.dart';
import 'package:wasle/features/orders/data/order_service.dart';

class MerchantIssuesScreen extends StatefulWidget {
  const MerchantIssuesScreen({super.key});

  @override
  State<MerchantIssuesScreen> createState() => _MerchantIssuesScreenState();
}

class _MerchantIssuesScreenState extends State<MerchantIssuesScreen> {
  final OrdersService _ordersService = OrdersService();

  bool _loading = true;
  String _search = '';
  String _selectedFilter = 'all';

  List<Map<String, dynamic>> _orders = [];

  static const List<String> _filters = [
    'all',
    'failed',
    'cancelled',
    'customer_not_available',
    'returning',
    'returned_to_store',
  ];

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
        _orders = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool _isIssueStatus(String status) {
    return status == 'failed' ||
        status == 'cancelled' ||
        status == 'customer_not_available' ||
        status == 'returning' ||
        status == 'returning_to_store' ||
        status == 'returned_to_store';
  }

  String _normalizedStatus(dynamic value) {
    final s = _safe(value, fallback: '').toLowerCase();

    if (s == 'returning_to_store') return 'returning';
    return s;
  }

  List<Map<String, dynamic>> _filteredOrders() {
    return _orders.where((order) {
      final status = _normalizedStatus(order['status']);
      if (!_isIssueStatus(status)) return false;

      final matchesFilter = _selectedFilter == 'all'
          ? true
          : status == _selectedFilter;

      final q = _search.trim().toLowerCase();
      final customer = _safe(order['customer_name']).toLowerCase();
      final tracking = _safe(order['tracking_code']).toLowerCase();
      final phone = _safe(order['customer_phone']).toLowerCase();
      final address = _safe(order['customer_address_text']).toLowerCase();

      final matchesSearch =
          q.isEmpty ||
          customer.contains(q) ||
          tracking.contains(q) ||
          phone.contains(q) ||
          address.contains(q) ||
          status.contains(q);

      return matchesFilter && matchesSearch;
    }).toList();
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

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      case 'customer_not_available':
        return 'Customer Not Available';
      case 'returning':
        return 'Returning';
      case 'returned_to_store':
        return 'Returned to Store';
      case 'all':
        return 'All';
      default:
        return s;
    }
  }

  String _issueMessage(String status) {
    switch (status) {
      case 'failed':
        return 'Delivery attempt failed. Review details and next action.';
      case 'cancelled':
        return 'This order has been cancelled.';
      case 'customer_not_available':
        return 'Customer could not be reached during delivery.';
      case 'returning':
        return 'This order is currently returning to the store.';
      case 'returned_to_store':
        return 'This order was returned to the store.';
      default:
        return 'Issue detected on this order.';
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'failed':
      case 'cancelled':
      case 'customer_not_available':
        return _W.red;
      case 'returning':
      case 'returned_to_store':
        return _W.amber;
      default:
        return _W.gray;
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'failed':
      case 'cancelled':
      case 'customer_not_available':
        return _W.redLt;
      case 'returning':
      case 'returned_to_store':
        return _W.amberLt;
      default:
        return _W.slateLt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders();

    return Scaffold(
      backgroundColor: _W.bg,
      appBar: AppBar(
        backgroundColor: _W.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Issues Center', style: _t(18, FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _W.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _W.border, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _W.redLt,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.warning_amber_outlined,
                                color: _W.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${filtered.length} issue orders',
                                    style: _t(15, FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Review failed, cancelled, and return-flow deliveries.',
                                    style: _t(
                                      12,
                                      FontWeight.w500,
                                      color: _W.gray,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: _W.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _W.border, width: 1.5),
                        ),
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: _t(14, FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search by name, phone, tracking code...',
                            hintStyle: _t(14, FontWeight.w400, color: _W.slate),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 20,
                              color: _W.slate,
                            ),
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
                          itemCount: _filters.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 7),
                          itemBuilder: (_, i) {
                            final filter = _filters[i];
                            final selected = _selectedFilter == filter;
                            final fg = filter == 'all'
                                ? (selected ? _W.blue : _W.gray)
                                : (selected ? _statusFg(filter) : _W.gray);
                            final bg = filter == 'all'
                                ? (selected ? _W.blueLt : _W.white)
                                : (selected ? _statusBg(filter) : _W.white);

                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedFilter = filter;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selected ? fg : _W.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  _statusLabel(filter),
                                  style: _t(12.5, FontWeight.w700, color: fg),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? _EmptyIssuesState(selectedFilter: _selectedFilter)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              14,
                              0,
                              14,
                              28 + MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final order = filtered[i];
                              final status = _normalizedStatus(order['status']);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _IssueCard(
                                  order: order,
                                  statusLabel: _statusLabel(status),
                                  issueMessage: _issueMessage(status),
                                  fg: _statusFg(status),
                                  bg: _statusBg(status),
                                  onTap: () => _openOrder(order),
                                ),
                              );
                            },
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
}) {
  return TextStyle(fontSize: size, fontWeight: w, color: color, height: height);
}

class _IssueCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String statusLabel;
  final String issueMessage;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;

  const _IssueCard({
    required this.order,
    required this.statusLabel,
    required this.issueMessage,
    required this.fg,
    required this.bg,
    required this.onTap,
  });

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: fg.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      statusLabel,
                      style: _t(11, FontWeight.w800, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.warning_amber_outlined,
                      color: fg,
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
              Text(
                issueMessage,
                style: _t(12.5, FontWeight.w600, color: fg, height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                _safe(
                  order['customer_address_text'],
                  fallback: 'No address available',
                ),
                style: _t(12.5, FontWeight.w500, color: _W.gray, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyIssuesState extends StatelessWidget {
  final String selectedFilter;

  const _EmptyIssuesState({required this.selectedFilter});

  @override
  Widget build(BuildContext context) {
    final title = selectedFilter == 'all'
        ? 'No issue orders'
        : 'No ${selectedFilter.replaceAll('_', ' ')} orders';

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
                  color: _W.redLt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: _W.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: _t(18, FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'No matching issue orders right now.',
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
