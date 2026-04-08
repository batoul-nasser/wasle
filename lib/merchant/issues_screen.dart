import 'package:flutter/material.dart';

import 'models/order_model.dart';
import 'order_details_screen.dart';
import 'services/order_service.dart';

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

const Set<String> _issueStatuses = {
  'failed',
  'cancelled',
  'returning',
  'returned_to_store',
};

const List<String> _filters = [
  'all',
  'failed',
  'cancelled',
  'returning',
  'returned_to_store',
];

String _filterLabel(String value) {
  switch (value) {
    case 'all':
      return 'All issues';
    case 'failed':
      return 'Failed';
    case 'cancelled':
      return 'Cancelled';
    case 'returning':
      return 'Returning';
    case 'returned_to_store':
      return 'Returned';
    default:
      return value;
  }
}

Color _statusFg(String s) {
  if (s == 'failed' || s == 'cancelled') return _W.red;
  if (s == 'returning' || s == 'returned_to_store') return _W.amber;
  return _W.gray;
}

Color _statusBg(String s) {
  if (s == 'failed' || s == 'cancelled') return _W.redLt;
  if (s == 'returning' || s == 'returned_to_store') return _W.amberLt;
  return _W.slateLt;
}

String _statusLabel(String s) {
  switch (s) {
    case 'failed':
      return 'Failed';
    case 'cancelled':
      return 'Cancelled';
    case 'returning':
      return 'Returning';
    case 'returned_to_store':
      return 'Returned';
    default:
      return s;
  }
}

class MerchantIssuesScreen extends StatefulWidget {
  const MerchantIssuesScreen({super.key});

  @override
  State<MerchantIssuesScreen> createState() => _MerchantIssuesScreenState();
}

class _MerchantIssuesScreenState extends State<MerchantIssuesScreen> {
  String _search = '';
  String _selectedFilter = 'all';

  Future<void> _refresh() async {
    await orderService.refresh();
  }

  List<OrderModel> _apply(List<OrderModel> orders) {
    return orders.where((o) {
      if (!_issueStatuses.contains(o.status)) return false;

      final matchesFilter =
          _selectedFilter == 'all' ? true : o.status == _selectedFilter;
      final q = _search.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          o.customerName.toLowerCase().contains(q) ||
          o.trackingCode.toLowerCase().contains(q);
      return matchesFilter && matchesSearch;
    }).toList();
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
        title: Text('Issues Center', style: _t(18, FontWeight.w800)),
      ),
      body: ValueListenableBuilder<List<OrderModel>>(
        valueListenable: orderService,
        builder: (context, orders, _) {
          final filtered = _apply(orders);
          final failedCount =
              orders.where((o) => o.status == 'failed').length;
          final cancelledCount =
              orders.where((o) => o.status == 'cancelled').length;
          final returningCount = orders
              .where((o) => o.status == 'returning' || o.status == 'returned_to_store')
              .length;

          return FutureBuilder<Map<String, Map<String, String?>>>(
            future: orderService.loadIssueSummaries(
              orderIds: filtered.map((o) => o.id),
            ),
            builder: (context, summarySnap) {
              final summaries = summarySnap.data ?? const <String, Map<String, String?>>{};

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                  children: [
                    _HeroCard(
                      total: failedCount + cancelledCount + returningCount,
                      failed: failedCount,
                      cancelled: cancelledCount,
                      returning: returningCount,
                    ),
                    const SizedBox(height: 14),
                    _SearchBox(
                      value: _search,
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) {
                          final item = _filters[i];
                          final selected = item == _selectedFilter;
                          return ChoiceChip(
                            label: Text(_filterLabel(item)),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedFilter = item),
                            selectedColor: _W.blueLt,
                            backgroundColor: _W.white,
                            side: const BorderSide(color: _W.border, width: 1.2),
                            labelStyle: _t(
                              13,
                              FontWeight.w700,
                              color: selected ? _W.blue : _W.gray,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            showCheckmark: false,
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: _filters.length,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Merchant issues', style: _t(16, FontWeight.w800)),
                        Text(
                          '${filtered.length} visible',
                          style: _t(13, FontWeight.w700, color: _W.gray),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const _EmptyState()
                    else
                      ...filtered.map((o) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _IssueCard(
                              order: o,
                              summary: summaries[o.id],
                            ),
                          )),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int total;
  final int failed;
  final int cancelled;
  final int returning;

  const _HeroCard({
    required this.total,
    required this.failed,
    required this.cancelled,
    required this.returning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _W.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _W.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Issue handling overview', style: _t(16, FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Review failed deliveries, merchant cancellations, and return-to-store outcomes from one place.',
            style: _t(13, FontWeight.w500, color: _W.gray, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Total issues',
                  value: '$total',
                  fg: _W.blue,
                  bg: _W.blueLt,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Failed',
                  value: '$failed',
                  fg: _W.red,
                  bg: _W.redLt,
                  icon: Icons.error_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Cancelled',
                  value: '$cancelled',
                  fg: _W.red,
                  bg: _W.redLt,
                  icon: Icons.cancel_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Returning',
                  value: '$returning',
                  fg: _W.amber,
                  bg: _W.amberLt,
                  icon: Icons.assignment_return_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color fg;
  final Color bg;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.fg,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(height: 10),
          Text(value, style: _t(22, FontWeight.w900, color: fg)),
          const SizedBox(height: 2),
          Text(label, style: _t(12, FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: _W.gray),
        hintText: 'Search by tracking code or customer',
        hintStyle: _t(13, FontWeight.w500, color: _W.gray),
        filled: true,
        fillColor: _W.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _W.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _W.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _W.blue, width: 1.6),
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final OrderModel order;
  final Map<String, String?>? summary;

  const _IssueCard({
    required this.order,
    this.summary,
  });

  String get _subtitle {
    final cancellationReason = summary?['cancellationReason']?.trim();
    final failedReason = summary?['failedReason']?.trim();
    final resolution = summary?['resolution']?.trim();
    final occurredAt = summary?['occurredAt']?.trim();

    if (order.status == 'cancelled') {
      if (cancellationReason != null && cancellationReason.isNotEmpty) {
        return occurredAt != null && occurredAt.isNotEmpty
            ? 'Reason: $cancellationReason · $occurredAt'
            : 'Reason: $cancellationReason';
      }
      return 'Merchant requested cancellation before pickup.';
    }
    if (order.status == 'returning' || order.status == 'returned_to_store') {
      if (resolution != null && resolution.isNotEmpty) return resolution;
      return 'This parcel is in the return-to-store path.';
    }
    if (failedReason != null && failedReason.isNotEmpty) {
      if (resolution != null && resolution.isNotEmpty) {
        return '$failedReason · $resolution';
      }
      return failedReason;
    }
    return 'This order needs merchant attention.';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final full = await orderService.getOrderWithTimeline(order.id);
          if (!context.mounted) return;
          if (full == null) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: full)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _W.white,
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
                      order.customerName,
                      style: _t(16, FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusBg(order.status),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(order.status),
                      style: _t(12, FontWeight.w800, color: _statusFg(order.status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tracking: ${order.trackingCode}',
                style: _t(13, FontWeight.w700, color: _W.gray),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                style: _t(13, FontWeight.w500, color: _W.gray, height: 1.45),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoPill(
                      icon: Icons.location_on_outlined,
                      label: order.address.isEmpty ? 'Address unavailable' : order.address,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoPill(
                      icon: Icons.schedule_outlined,
                      label: order.createdAt.isEmpty ? 'Recently updated' : order.createdAt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Open details →',
                  style: _t(13, FontWeight.w800, color: _W.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _W.slateLt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _W.gray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(12, FontWeight.w700, color: _W.gray),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _W.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _W.border, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: _W.blueLt,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined, color: _W.blue),
          ),
          const SizedBox(height: 12),
          Text('No issues match this view', style: _t(18, FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'When orders fail, get cancelled, or enter the return flow, they will appear here for the merchant to review.',
            style: _t(13, FontWeight.w500, color: _W.gray, height: 1.45),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
