import 'package:flutter/material.dart';
import 'models/order_model.dart';
import 'services/order_service.dart';

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
  static const slateLt = Color(0xFFF1F4FC);
  static const statusCreated = Color(0xFF94A3B8);
  static const white60 = Color(0x99FFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const white13 = Color(0x22FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white07 = Color(0x12FFFFFF);
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

Color _statusColor(String s) {
  if (s == 'delivered') return _W.green;
  if (s == 'failed' || s == 'cancelled') return _W.red;
  if (s == 'returning' || s == 'returned_to_store') return _W.amber;
  if (s == 'assigned' || s == 'in_transit') return _W.blue;
  return _W.statusCreated;
}

Color _statusBg(String s) {
  if (s == 'delivered') return _W.greenLt;
  if (s == 'failed' || s == 'cancelled') return _W.redLt;
  if (s == 'returning' || s == 'returned_to_store') return _W.amberLt;
  if (s == 'assigned' || s == 'in_transit') return _W.blueLt;
  return _W.slateLt;
}

String _statusLabel(String s) {
  if (s == 'created') return 'Created';
  if (s == 'assigned') return 'Assigned';
  if (s == 'in_transit') return 'In Transit';
  if (s == 'delivered') return 'Delivered';
  if (s == 'failed') return 'Failed';
  if (s == 'cancelled') return 'Cancelled';
  if (s == 'returning') return 'Returning';
  if (s == 'returned_to_store') return 'Returned';
  return s;
}

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late OrderModel _order;
  bool _loadingTimeline = true;
  bool _loadingAssignment = true;
  bool _submittingCancellation = false;

  String? _assignedCompany;
  String? _driverName;
  String? _driverPhone;
  String? _assignmentTime;
  String? _expectedPickupTime;
  String? _failedReason;
  String? _resolution;
  String? _cancellationReason;
  String? _exceptionOccurredAt;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    await Future.wait([
      _loadTimeline(),
      _loadAssignmentDetails(),
      _loadExceptionDetails(),
    ]);
  }

  Future<void> _loadTimeline() async {
    try {
      final events = await orderService.loadTimeline(_order.id);
      if (mounted) {
        setState(() {
          _order = _order.withTimeline(events);
          _loadingTimeline = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTimeline = false);
      }
    }
  }

  Future<void> _loadAssignmentDetails() async {
    try {
      final details = await orderService.loadAssignmentDetails(_order.id);
      if (!mounted) return;

      setState(() {
        _assignedCompany = details['assignedCompany'];
        _driverName = details['driverName'];
        _driverPhone = details['driverPhone'];
        _assignmentTime = details['assignmentTime'];
        _expectedPickupTime = details['expectedPickupTime'];
        _loadingAssignment = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAssignment = false);
      }
    }
  }

  Future<void> _loadExceptionDetails() async {
    final details = await orderService.loadExceptionDetails(_order.id);
    if (!mounted) return;
    setState(() {
      _failedReason = details['failedReason'] ?? _order.failedReason;
      _resolution = details['resolution'] ?? _order.resolution;
      _cancellationReason = details['cancellationReason'];
      _exceptionOccurredAt = details['occurredAt'];
    });
  }

  bool get _hasException =>
      _order.status == 'failed' ||
      _order.status == 'cancelled' ||
      _order.status == 'returning' ||
      _order.status == 'returned_to_store' ||
      _failedReason != null ||
      _resolution != null ||
      _cancellationReason != null;

  bool get _canRequestCancellation =>
      _order.status == 'created' || _order.status == 'assigned';

  String get _exceptionReasonText {
    if (_order.status == 'cancelled') return 'Cancellation requested';
    if (_failedReason != null && _failedReason!.trim().isNotEmpty) {
      return _failedReason!;
    }
    if (_order.status == 'returning' || _order.status == 'returned_to_store') {
      return 'Customer not available';
    }
    return 'Exception outcome';
  }

  String? get _exceptionResolutionText {
    if (_order.status == 'cancelled') {
      final note = _cancellationReason?.trim();
      final when = _exceptionOccurredAt?.trim();
      if (note != null && note.isNotEmpty && when != null && when.isNotEmpty) {
        return 'Reason: $note · $when';
      }
      if (note != null && note.isNotEmpty) return 'Reason: $note';
      return 'Requested by merchant before pickup.';
    }
    if (_resolution != null && _resolution!.trim().isNotEmpty) {
      return _resolution;
    }
    if (_order.status == 'returning') return 'Return to store is in progress.';
    if (_order.status == 'returned_to_store') return 'Parcel returned to store.';
    return null;
  }

  bool get _hasCompany =>
      _assignedCompany != null && _assignedCompany!.trim().isNotEmpty;

  bool get _hasDriver =>
      _driverName != null && _driverName!.trim().isNotEmpty;

  String get _assignmentHeadline {
    if (_hasCompany && _hasDriver) {
      return 'Order is assigned and being handled.';
    }
    if (_hasCompany && !_hasDriver) {
      return 'Assigned to a delivery company. Waiting for driver assignment.';
    }
    return 'This order is still waiting for assignment.';
  }

  String get _assignmentSubline {
    if (_hasCompany && _hasDriver) {
      return 'Company and driver details are now available.';
    }
    if (_hasCompany && !_hasDriver) {
      return 'A company accepted the order, but no driver has started handling it yet.';
    }
    return 'Once a company or driver picks it up, details will appear here automatically.';
  }

  void _showActionInfo(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action is not connected yet.'),
        backgroundColor: _W.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _openCancellationDialog() async {
    if (!_canRequestCancellation) {
      _showActionInfo('Cancellation is only available before pickup');
      return;
    }

    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Request Cancellation'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Enter cancellation reason',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _submittingCancellation = true);
    try {
      await orderService.requestCancellation(
        orderId: _order.id,
        currentStatus: _order.status,
        reason: reason,
      );
      final refreshed = await orderService.getOrderWithTimeline(_order.id);
      if (!mounted) return;
      setState(() {
        if (refreshed != null) {
          _order = refreshed;
        } else {
          _order = _order.copyWith(status: 'cancelled');
        }
      });
      await _loadExceptionDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancellation request submitted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingCancellation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _W.bg,
      appBar: _buildAppBar(context),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          14,
          8,
          14,
          28 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _HeaderCard(order: _order),
          const SizedBox(height: 12),
          if (_hasException) ...[
            _ExceptionBanner(
              reason: _exceptionReasonText,
              resolution: _exceptionResolutionText,
            ),
            const SizedBox(height: 12),
          ],
          _SectionCard(
            icon: Icons.receipt_long_outlined,
            iconColor: _W.blue,
            iconBg: _W.blueLt,
            title: 'Order Summary',
            child: Column(
              children: [
                _InfoRow(label: 'Order ID', value: _order.id),
                _InfoRow(
                  label: 'Tracking Code',
                  value: _order.trackingCode,
                  valueColor: _W.blue,
                ),
                _InfoRow(
                  label: 'Status',
                  child: _StatusBadge(status: _order.status),
                ),
                _InfoRow(label: 'Created At', value: _order.createdAt),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.person_outline,
            iconColor: _W.blue,
            iconBg: _W.blueLt,
            title: 'Customer Information',
            child: Column(
              children: [
                _InfoRow(label: 'Name', value: _order.customerName),
                _InfoRow(
                  label: 'Phone',
                  value: _order.customerPhone,
                  valueColor: _W.blue,
                ),
                _InfoRow(label: 'Email', value: _order.customerEmail ?? '—'),
                _InfoRow(
                  label: 'Notes',
                  value: _order.notes ?? '—',
                  valueColor: _W.gray,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.location_on_outlined,
            iconColor: _W.amber,
            iconBg: _W.amberLt,
            title: 'Delivery Information',
            child: Column(
              children: [
                _InfoRow(label: 'Address', value: _order.address),
                _InfoRow(label: 'Pickup Method', value: _order.pickupMethod),
                _InfoRow(
                  label: 'COD Amount',
                  value: '\$${_order.codAmount.toStringAsFixed(2)}',
                  valueColor: _W.blue,
                ),
                _InfoRow(
                  label: 'Time Window',
                  value: _order.preferredTimeWindow ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.local_shipping_outlined,
            iconColor: _W.green,
            iconBg: _W.greenLt,
            title: 'Assignment Information',
            child: _loadingAssignment
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: _W.blue,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AssignmentBanner(
                        hasCompany: _hasCompany,
                        hasDriver: _hasDriver,
                        title: _assignmentHeadline,
                        subtitle: _assignmentSubline,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(label: 'Company', value: _assignedCompany ?? '—'),
                      _InfoRow(label: 'Driver', value: _driverName ?? '—'),
                      _InfoRow(
                        label: 'Driver Phone',
                        value: _driverPhone ?? '—',
                        valueColor: _driverPhone != null ? _W.blue : _W.gray,
                      ),
                      _InfoRow(
                        label: 'Assigned At',
                        value: _assignmentTime ?? '—',
                      ),
                      _InfoRow(
                        label: 'Expected Pickup',
                        value: _expectedPickupTime ?? '—',
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.timeline_outlined,
            iconColor: _W.blue,
            iconBg: _W.blueLt,
            title: 'Order Timeline',
            child: _loadingTimeline
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: _W.blue,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : _order.timeline.isEmpty
                    ? Text(
                        'No events yet',
                        style: _t(13, FontWeight.w500, color: _W.gray),
                      )
                    : Column(
                        children: List.generate(
                          _order.timeline.length,
                          (i) => _TimelineStep(
                            title: _order.timeline[i],
                            isLast: i == _order.timeline.length - 1,
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.bolt_outlined,
            iconColor: _W.slate,
            iconBg: _W.slateLt,
            title: 'Merchant Actions',
            child: Column(
              children: [
                _ActionBtn(
                  icon: Icons.flash_on_outlined,
                  label: 'Request Urgent Pickup',
                  color: _W.amber,
                  bg: _W.amberLt,
                  borderColor: _W.amber.withOpacity(0.20),
                  onTap: () => _showActionInfo('Urgent pickup request'),
                ),
                const SizedBox(height: 10),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: 'Contact Support',
                  color: _W.blue,
                  bg: _W.blueLt,
                  borderColor: _W.blue.withOpacity(0.20),
                  onTap: () => _showActionInfo('Support contact'),
                ),
                const SizedBox(height: 10),
                _ActionBtn(
                  icon: _submittingCancellation ? Icons.hourglass_top_outlined : Icons.cancel_outlined,
                  label: _order.status == 'cancelled'
                      ? 'Cancellation Submitted'
                      : _canRequestCancellation
                          ? 'Request Cancellation'
                          : 'Cancellation Unavailable',
                  color: _W.red,
                  bg: _W.redLt,
                  borderColor: _W.red.withOpacity(0.18),
                  onTap: _submittingCancellation
                      ? () {}
                      : _canRequestCancellation
                          ? _openCancellationDialog
                          : () => _showActionInfo('Cancellation is no longer available for this order'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _W.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _W.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _W.border, width: 1.5),
            ),
            child: const Icon(
              Icons.chevron_left,
              size: 22,
              color: _W.navy,
            ),
          ),
        ),
      ),
      leadingWidth: 60,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Details', style: _t(17, FontWeight.w900)),
          Text(
            'Track & manage this delivery',
            style: _t(11.5, FontWeight.w500, color: _W.gray),
          ),
        ],
      ),
    );
  }
}

class _AssignmentBanner extends StatelessWidget {
  final bool hasCompany;
  final bool hasDriver;
  final String title;
  final String subtitle;

  const _AssignmentBanner({
    required this.hasCompany,
    required this.hasDriver,
    required this.title,
    required this.subtitle,
  });

  Color get _bg {
    if (hasCompany && hasDriver) return _W.greenLt;
    if (hasCompany && !hasDriver) return _W.amberLt;
    return _W.blueLt;
  }

  Color get _fg {
    if (hasCompany && hasDriver) return _W.green;
    if (hasCompany && !hasDriver) return _W.amber;
    return _W.blue;
  }

  IconData get _icon {
    if (hasCompany && hasDriver) return Icons.check_circle_outline;
    if (hasCompany && !hasDriver) return Icons.schedule_outlined;
    return Icons.hourglass_top_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fg.withOpacity(0.18), width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 18, color: _fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _t(13, FontWeight.w800, color: _fg),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: _t(12, FontWeight.w500, color: _fg, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final OrderModel order;

  const _HeaderCard({required this.order});

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
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: _W.white07,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _W.white13,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.trackingCode,
                          style: _t(20, FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.customerName,
                          style: _t(13, FontWeight.w600, color: _W.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.customerPhone,
                          style: _t(12.5, FontWeight.w500, color: _W.white60),
                        ),
                        const SizedBox(height: 10),
                        _WhiteStatusBadge(status: order.status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (order.codAmount > 0)
                    _MetaChip(
                      icon: Icons.credit_card_outlined,
                      label: 'COD \$${order.codAmount.toStringAsFixed(2)}',
                    ),
                  _MetaChip(
                    icon: Icons.storefront_outlined,
                    label: order.pickupMethod,
                  ),
                  if (order.preferredTimeWindow != null)
                    _MetaChip(
                      icon: Icons.access_time_outlined,
                      label: order.preferredTimeWindow!,
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

class _WhiteStatusBadge extends StatelessWidget {
  final String status;

  const _WhiteStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _W.white20,
        border: Border.all(color: _W.white20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: _t(12, FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: _W.white13,
        border: Border.all(color: _W.white20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: _t(11.5, FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ExceptionBanner extends StatelessWidget {
  final String? reason;
  final String? resolution;

  const _ExceptionBanner({this.reason, this.resolution});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _W.redLt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _W.red.withOpacity(0.18),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _W.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_outlined,
              size: 18,
              color: _W.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason ?? 'Exception Outcome',
                  style: _t(13.5, FontWeight.w800, color: _W.red),
                ),
                if (resolution != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Resolution: $resolution',
                    style: _t(12, FontWeight.w500, color: _W.red, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
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
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
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
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(title, style: _t(14.5, FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _W.border),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? child;

  const _InfoRow({
    required this.label,
    this.value,
    this.valueColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: _t(12, FontWeight.w600, color: _W.gray),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: child ??
                Text(
                  value ?? '—',
                  style: _t(
                    13,
                    FontWeight.w700,
                    color: valueColor ?? _W.navy,
                  ),
                  textAlign: TextAlign.right,
                ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _statusColor(status).withOpacity(0.25)),
      ),
      child: Text(
        _statusLabel(status),
        style: _t(11.5, FontWeight.w800, color: _statusColor(status)),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _W.blue,
                shape: BoxShape.circle,
                border: Border.all(color: _W.blueLt, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: _W.blueLt,
                margin: const EdgeInsets.symmetric(vertical: 3),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
            child: Text(title, style: _t(13, FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final Color borderColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withOpacity(0.10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: _t(14, FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}