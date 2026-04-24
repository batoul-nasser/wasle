import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wasle/core/utils/app_date_time.dart';
import 'package:wasle/features/orders/data/order_service.dart';

class MerchantOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> initialOrder;

  const MerchantOrderDetailsScreen({
    super.key,
    required this.initialOrder,
  });

  @override
  State<MerchantOrderDetailsScreen> createState() =>
      _MerchantOrderDetailsScreenState();
}

class _MerchantOrderDetailsScreenState
    extends State<MerchantOrderDetailsScreen> {
  final OrdersService _ordersService = OrdersService();

  late Map<String, dynamic> _order;
  List<Map<String, dynamic>> _events = [];
  String? _companyName;
  Map<String, String>? _pickupPointDetails;

  bool _loading = true;
  bool _loadingTimeline = true;
  bool _loadingAssignment = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.initialOrder);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingTimeline = true;
        _loadingAssignment = true;
      });
    }

    try {
      final orderId = _safe(_order['id'], fallback: '');

      if (orderId.isNotEmpty) {
        final refreshedOrder = await _ordersService.getOrderById(orderId);
        if (refreshedOrder != null) {
          _order = Map<String, dynamic>.from(refreshedOrder);
        }
      }

      await Future.wait([
        _loadTimeline(),
        _loadAssignmentDetails(),
        _loadPickupPointDetails(),
      ]);
    } catch (_) {
      // keep current snapshot
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadTimeline() async {
    try {
      final orderId = _safe(_order['id'], fallback: '');

      if (orderId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _events = [];
          _loadingTimeline = false;
        });
        return;
      }

      final events = await _ordersService.getOrderEvents(orderId);

      if (!mounted) return;
      setState(() {
        _events = List<Map<String, dynamic>>.from(events);
        _loadingTimeline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _events = [];
        _loadingTimeline = false;
      });
    }
  }

  Future<void> _loadAssignmentDetails() async {
    try {
      final companyId = _safe(_order['delivery_company_id'], fallback: '');

      if (companyId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _companyName = null;
          _loadingAssignment = false;
        });
        return;
      }

      final companyName = await _ordersService.getCompanyNameById(companyId);

      if (!mounted) return;
      setState(() {
        _companyName = companyName;
        _loadingAssignment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _companyName = null;
        _loadingAssignment = false;
      });
    }
  }

  Future<void> _loadPickupPointDetails() async {
    try {
      final pickupPointId = _safe(_order['pickup_point_id'], fallback: '');

      if (pickupPointId.isEmpty || pickupPointId == '-') {
        if (!mounted) return;
        setState(() {
          _pickupPointDetails = null;
        });
        return;
      }

      final details = await _ordersService.getPickupPointById(pickupPointId);

      if (!mounted) return;
      setState(() {
        _pickupPointDetails = details;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickupPointDetails = null;
      });
    }
  }

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  DateTime? _tryParseDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _labelFromKey(String value) {
    return value
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String get _currentStatus {
    return _safe(_order['status'], fallback: 'created').toLowerCase();
  }

  bool get _canCancel {
    const cancellableStatuses = {
      'created',
      'pending',
      'confirmed_by_merchant',
      'ready_for_driver_pickup',
      'assigned',
      'assigned_to_company',
      'assigned_to_driver',
      'pending_driver_receipt',
      'driver_received_order',
    };
    return cancellableStatuses.contains(_currentStatus);
  }

  bool get _hasPayment {
    return _order['_payment'] != null ||
        _safe(_order['payment_method'], fallback: '').isNotEmpty ||
        _safe(_order['payment_amount'], fallback: '').isNotEmpty;
  }

  String get _paymentMethodLabel {
    final method = _safe(_order['payment_method'], fallback: '').toLowerCase();
    switch (method) {
      case 'cash_at_pickup':
      case 'cod':
        return 'Cash at Pickup';
      case 'whish_online':
        return 'Whish Online';
      case 'card':
        return 'Card';
      default:
        return method.isEmpty ? 'Payment' : _labelFromKey(method);
    }
  }

  String get _paymentStatusLabel {
    final status = _safe(_order['payment_status'], fallback: 'pending');
    return _labelFromKey(status);
  }

  String get _paymentAmountLabel {
    final amount = _order['payment_amount'];
    if (amount is num) return '\$${amount.toStringAsFixed(2)}';
    final text = _safe(amount, fallback: '');
    return text.isEmpty ? '-' : '\$$text';
  }

  bool get _hasPickupPoint {
    final pickupPointId = _safe(_order['pickup_point_id'], fallback: '');
    return pickupPointId.isNotEmpty && pickupPointId != '-';
  }

  String get _pickupMethodLabel {
    return _hasPickupPoint ? 'Pickup Point' : 'From Store';
  }

  String get _pickupPointDisplay {
    final pickupPointName = _pickupPointDetails?['name']?.trim() ?? '';
    final pickupPointAddress = _pickupPointDetails?['address']?.trim() ?? '';

    if (pickupPointName.isNotEmpty) {
      if (pickupPointAddress.isNotEmpty) {
        return '$pickupPointName — $pickupPointAddress';
      }
      return pickupPointName;
    }

    return '-';
  }

  String get _dropoffAddressDisplay {
    return _safe(
      _order['customer_address_text'],
      fallback: 'No address provided',
    );
  }

  String get _packageDescriptionDisplay {
    return _safe(_order['parcel_description'], fallback: '-');
  }

  String get _itemCountDisplay {
    final value = _order['item_count'];
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  String get _weightDisplay {
    final value = _order['estimated_weight'];
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : '$text kg';
  }

  String get _volumeDisplay {
    final value = _order['estimated_volume'];
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : '$text m³';
  }

  List<Map<String, dynamic>> get _timelineEvents {
    final sorted = List<Map<String, dynamic>>.from(_events)
      ..sort((a, b) {
        final aDate = _tryParseDate(a['created_at']);
        final bDate = _tryParseDate(b['created_at']);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;
        return aDate.compareTo(bDate);
      });

    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final event in sorted) {
      final type = _safe(event['event_type'], fallback: 'event');
      final createdAt = _safe(event['created_at'], fallback: '');
      final note = _safe(event['note'], fallback: '');
      final key = '$type|$createdAt|$note';

      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(event);
    }

    return result;
  }

  Map<String, dynamic>? _latestEventOfTypes(List<String> types) {
    final set = types.map((e) => e.toLowerCase()).toSet();

    for (final event in _timelineEvents.reversed) {
      final type = _safe(event['event_type'], fallback: '').toLowerCase();
      if (set.contains(type)) return event;
    }

    return null;
  }

  String _titleize(String value) {
    return value
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  String? _extractResolutionFromNote(String note) {
    final match = RegExp(
      r'resolution\s*:\s*([a-zA-Z _-]+)',
      caseSensitive: false,
    ).firstMatch(note);

    if (match != null) {
      final raw = (match.group(1) ?? '').trim();
      if (raw.isNotEmpty) {
        return _titleize(raw.replaceAll('_', ' '));
      }
    }

    final lower = note.toLowerCase();

    if (lower.contains('return to store') ||
        lower.contains('returned to store') ||
        lower.contains('returning to store') ||
        lower.contains('returned to merchant') ||
        lower.contains('returning to merchant')) {
      return 'Return to Merchant';
    }

    if (lower.contains('rescheduled') || lower.contains('reschedule')) {
      return 'Rescheduled';
    }

    if (lower.contains('pickup point')) {
      return 'Pickup Point Drop';
    }

    return null;
  }

  String? get _rootReason {
    final failed = _latestEventOfTypes(['delivery_failed', 'failed']);
    final failedNote = _safe(failed?['note'], fallback: '').toLowerCase();

    if (failedNote.contains('customer not available')) {
      return 'Customer not available';
    }

    if (failed != null) {
      return 'Delivery failed';
    }

    if (_currentStatus == 'cancelled') return 'Cancellation requested';

    if (_currentStatus == 'dropped_at_pickup_point') {
      return 'Dropped at pickup point';
    }

    if (_currentStatus == 'rescheduled') {
      return 'Delivery rescheduled';
    }

    if (_currentStatus == 'returned_to_store' ||
        _currentStatus == 'returned_to_merchant') {
      return 'Returned to merchant';
    }

    if (_currentStatus == 'returning' ||
        _currentStatus == 'returning_to_store' ||
        _currentStatus == 'return_in_progress') {
      return 'Returning to merchant';
    }

    return null;
  }

  String? get _rootResolution {
    for (final event in _timelineEvents.reversed) {
      final note = _safe(event['note'], fallback: '');
      final resolution = _extractResolutionFromNote(note);
      if (resolution != null) return resolution;
    }

    if (_currentStatus == 'dropped_at_pickup_point') {
      return 'Pickup Point Drop';
    }

    if (_currentStatus == 'rescheduled') {
      return 'Rescheduled';
    }

    if (_currentStatus == 'returned_to_store' ||
        _currentStatus == 'returned_to_merchant') {
      return 'Return to Merchant Completed';
    }

    if (_currentStatus == 'returning' ||
        _currentStatus == 'returning_to_store' ||
        _currentStatus == 'return_in_progress') {
      return 'Return to Merchant In Progress';
    }

    if (_currentStatus == 'cancelled') {
      final cancelled = _latestEventOfTypes(['cancelled']);
      final note = _safe(cancelled?['note'], fallback: '');
      if (note.toLowerCase().startsWith('reason:')) {
        return note.substring(7).trim();
      }
      return 'Cancellation recorded';
    }

    return null;
  }

  bool get _hasException => _rootReason != null;

  String _eventTitle(String raw) {
    switch (raw.toLowerCase()) {
      case 'order_created':
        return 'Order Created';
      case 'confirmed_by_merchant':
        return 'Confirmed by Merchant';
      case 'ready_for_driver_pickup':
        return 'Ready for Driver Pickup';
      case 'pending_driver_receipt':
        return 'Pending Driver Receipt';
      case 'driver_received_order':
        return 'Driver Received Order';
      case 'assigned_to_company':
        return 'Assigned to Company';
      case 'assigned_to_driver':
        return 'Assigned to Driver';
      case 'picked_up':
        return 'Picked Up';
      case 'picked_up_from_merchant':
        return 'Picked Up from Merchant';
      case 'in_transit':
        return 'In Transit';
      case 'in_transit_to_pickup_point':
        return 'In Transit to Pickup Point';
      case 'arrived_at_pickup_point':
        return 'Arrived at Pickup Point';
      case 'stored_at_pickup_point':
        return 'Stored at Pickup Point';
      case 'ready_for_customer_pickup':
        return 'Ready for Customer Pickup';
      case 'picked_up_by_customer':
        return 'Picked Up by Customer';
      case 'dropped_at_pickup_point':
        return 'Dropped at Pickup Point';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'delivery_failed':
      case 'failed':
        return 'Delivery Failed';
      case 'cancelled':
        return 'Cancelled';
      case 'rescheduled':
        return 'Rescheduled';
      case 'customer_not_available':
        return 'Customer Not Available';
      case 'returning':
      case 'returning_to_store':
      case 'return_in_progress':
        return 'Returning to Merchant';
      case 'returned_to_store':
      case 'returned_to_merchant':
        return 'Returned to Merchant';
      case 'note_added':
        return 'Note Added';
      case 'agent_cash_collected':
        return 'Cash Collected';
      case 'remittance_sent':
        return 'Remittance Sent';
      default:
        return _labelFromKey(raw);
    }
  }

  String _formatDate(dynamic value) {
    return AppDateTime.format(value);
  }

  void _showSafeSnack(String message) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<String?> _openCancellationReasonPage() async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _CancellationReasonScreen(),
      ),
    );
  }

  Future<void> _requestCancellation() async {
    if (_actionLoading) return;

    if (!_canCancel) {
      _showSafeSnack('This order can only be cancelled before pickup.');
      return;
    }

    final reason = await _openCancellationReasonPage();

    if (!mounted) return;
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _actionLoading = true);

    try {
      await _ordersService.requestCancellation(
        orderId: _safe(_order['id'], fallback: ''),
        reason: reason.trim(),
      );

      await _loadDetails();

      if (!mounted) return;
      _showSafeSnack('Order cancelled successfully.');
    } catch (e) {
      if (!mounted) return;
      _showSafeSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentStatus;
    final trackingCode = _safe(_order['tracking_code']);
    final companyId = _safe(_order['delivery_company_id'], fallback: '');
    final hasCompany = companyId.isNotEmpty && companyId != '-';
    final branchId = _safe(_order['branch_id'], fallback: '');

    return Scaffold(
      backgroundColor: _W.bg,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  14,
                  8,
                  14,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  _HeaderCard(
                    customerName: _safe(
                      _order['customer_name'],
                      fallback: 'Customer',
                    ),
                    customerPhone: _safe(_order['customer_phone']),
                    trackingCode: trackingCode,
                    status: status,
                  ),
                  const SizedBox(height: 12),
                  if (_hasException) ...[
                    _ExceptionBanner(
                      reason: _rootReason,
                      resolution: _rootResolution,
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
                        _InfoRow(label: 'Order ID', value: _safe(_order['id'])),
                        _InfoRow(
                          label: 'Tracking Code',
                          value: trackingCode,
                          valueColor: _W.blue,
                        ),
                        _InfoRow(
                          label: 'Status',
                          child: _StatusBadge(status: status),
                        ),
                        _InfoRow(
                          label: 'Created At',
                          value: _formatDate(_order['created_at']),
                        ),
                        _InfoRow(
                          label: 'Updated At',
                          value: _formatDate(_order['updated_at']),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_hasPayment) ...[
                    _SectionCard(
                      icon: Icons.payments_outlined,
                      iconColor: _W.green,
                      iconBg: _W.greenLt,
                      title: 'Payment Information',
                      child: Column(
                        children: [
                          _InfoRow(label: 'Method', value: _paymentMethodLabel),
                          _InfoRow(
                            label: 'Status',
                            value: _paymentStatusLabel,
                            valueColor: _W.amber,
                          ),
                          _InfoRow(
                            label: 'Amount',
                            value: _paymentAmountLabel,
                            valueColor: _W.blue,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SectionCard(
                    icon: Icons.person_outline,
                    iconColor: _W.blue,
                    iconBg: _W.blueLt,
                    title: 'Customer Information',
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Name',
                          value: _safe(
                            _order['customer_name'],
                            fallback: 'Customer',
                          ),
                        ),
                        _InfoRow(
                          label: 'Phone',
                          value: _safe(_order['customer_phone']),
                          valueColor: _W.blue,
                        ),
                        if (_safe(_order['customer_email'], fallback: '')
                            .isNotEmpty)
                          _InfoRow(
                            label: 'Email',
                            value: _safe(_order['customer_email']),
                            valueColor: _W.blue,
                          ),
                        _InfoRow(
                          label: 'Notes',
                          value: _safe(_order['notes'], fallback: '-'),
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
                        _InfoRow(
                          label: 'Pickup Method',
                          value: _pickupMethodLabel,
                        ),
                        if (_hasPickupPoint && _pickupPointDisplay != '-')
                          _InfoRow(
                            label: 'Pickup Point',
                            value: _pickupPointDisplay,
                          ),
                        _InfoRow(
                          label: 'Dropoff Address',
                          value: _dropoffAddressDisplay,
                        ),
                        if (branchId.isNotEmpty && branchId != '-')
                          _InfoRow(
                            label: 'Branch',
                            value: branchId,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: _W.slate,
                    iconBg: _W.slateLt,
                    title: 'Package Information',
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Description',
                          value: _packageDescriptionDisplay,
                        ),
                        _InfoRow(
                          label: 'Item Count',
                          value: _itemCountDisplay,
                        ),
                        _InfoRow(
                          label: 'Weight',
                          value: _weightDisplay,
                        ),
                        _InfoRow(
                          label: 'Volume',
                          value: _volumeDisplay,
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
                                hasCompany: hasCompany,
                                title: hasCompany
                                    ? 'Order is assigned to a delivery company.'
                                    : 'This order is still waiting for assignment.',
                                subtitle: hasCompany
                                    ? 'Company details are now available below.'
                                    : 'Once a company accepts it, assignment details will appear here.',
                              ),
                              const SizedBox(height: 12),
                              _InfoRow(
                                label: 'Delivery Company',
                                value: hasCompany
                                    ? ((_companyName?.trim().isNotEmpty ?? false)
                                        ? _companyName!
                                        : companyId)
                                    : 'Waiting for assignment',
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
                        : _timelineEvents.isEmpty
                            ? Text(
                                'No timeline events yet.',
                                style: _t(
                                  13,
                                  FontWeight.w500,
                                  color: _W.gray,
                                ),
                              )
                            : Column(
                                children: List.generate(_timelineEvents.length, (
                                  i,
                                ) {
                                  final event = _timelineEvents[i];
                                  final title = _eventTitle(
                                    _safe(event['event_type'], fallback: 'event'),
                                  );
                                  final note = _safe(event['note'], fallback: '');
                                  final createdAt = _formatDate(
                                    event['created_at'],
                                  );

                                  return _TimelineStep(
                                    title: title,
                                    subtitle: note.isEmpty
                                        ? createdAt
                                        : '$createdAt\n$note',
                                    isLast: i == _timelineEvents.length - 1,
                                  );
                                }),
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
                          icon: Icons.cancel_outlined,
                          label: status == 'cancelled'
                              ? 'Cancellation Submitted'
                              : 'Request Cancellation',
                          sublabel: status == 'cancelled'
                              ? 'This order is already cancelled.'
                              : _canCancel
                                  ? 'Cancel this order before pickup.'
                                  : 'Cancellation is closed after pickup.',
                          color: _W.red,
                          bg: _W.redLt,
                          borderColor: _W.red.withValues(alpha: 0.18),
                          onTap: (_actionLoading || status == 'cancelled')
                              ? null
                              : _requestCancellation,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

class _CancellationReasonScreen extends StatefulWidget {
  const _CancellationReasonScreen();

  @override
  State<_CancellationReasonScreen> createState() =>
      _CancellationReasonScreenState();
}

class _CancellationReasonScreenState extends State<_CancellationReasonScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _W.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _W.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Cancellation Reason', style: _t(18, FontWeight.w900)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _W.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _W.border, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Why are you cancelling this order?',
                              style: _t(15, FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Write a clear reason before submitting.',
                              style: _t(
                                13,
                                FontWeight.w500,
                                color: _W.gray,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _controller,
                              minLines: 3,
                              maxLines: 4,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                hintText: 'Customer requested cancellation...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: const Text('Submit Cancellation'),
                        ),
                      ),
                    ],
                  ),
                ),
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

class _AssignmentBanner extends StatelessWidget {
  final bool hasCompany;
  final String title;
  final String subtitle;

  const _AssignmentBanner({
    required this.hasCompany,
    required this.title,
    required this.subtitle,
  });

  Color get _bg => hasCompany ? _W.greenLt : _W.blueLt;
  Color get _fg => hasCompany ? _W.green : _W.blue;
  IconData get _icon =>
      hasCompany ? Icons.check_circle_outline : Icons.hourglass_top_outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fg.withValues(alpha: 0.18), width: 1.4),
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
                Text(title, style: _t(13, FontWeight.w800, color: _fg)),
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
  final String customerName;
  final String customerPhone;
  final String trackingCode;
  final String status;

  const _HeaderCard({
    required this.customerName,
    required this.customerPhone,
    required this.trackingCode,
    required this.status,
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
                          trackingCode,
                          style: _t(20, FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          customerName,
                          style: _t(13, FontWeight.w600, color: _W.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customerPhone,
                          style: _t(12.5, FontWeight.w500, color: _W.white60),
                        ),
                        const SizedBox(height: 10),
                        _WhiteStatusBadge(status: status),
                      ],
                    ),
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
        border: Border.all(color: _W.red.withValues(alpha: 0.18), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _W.red.withValues(alpha: 0.12),
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
                if (resolution != null && resolution!.trim().isNotEmpty) ...[
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
              Expanded(
                child: Text(
                  title,
                  style: _t(14.5, FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 320;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _t(12, FontWeight.w600, color: _W.gray)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: child ??
                      Text(
                        value ?? '-',
                        style: _t(
                          13,
                          FontWeight.w700,
                          color: valueColor ?? _W.navy,
                        ),
                      ),
                ),
              ],
            );
          }

          return Row(
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
                      value ?? '-',
                      style: _t(
                        13,
                        FontWeight.w700,
                        color: valueColor ?? _W.navy,
                      ),
                      textAlign: TextAlign.right,
                    ),
              ),
            ],
          );
        },
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
        border: Border.all(
          color: _statusColor(status).withValues(alpha: 0.25),
        ),
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
  final String subtitle;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
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
                height: 42,
                color: _W.blueLt,
                margin: const EdgeInsets.symmetric(vertical: 3),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(13, FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: _t(12, FontWeight.w500, color: _W.gray, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bg;
  final Color borderColor;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: color.withValues(alpha: 0.10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: _t(14, FontWeight.w700, color: color)),
                      const SizedBox(height: 2),
                      Text(
                        sublabel,
                        style: _t(
                          12,
                          FontWeight.w500,
                          color: color,
                          height: 1.35,
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

String _statusLabel(String s) {
  switch (s.toLowerCase()) {
    case 'created':
      return 'Created';
    case 'pending':
      return 'Pending';
    case 'confirmed_by_merchant':
      return 'Confirmed by Merchant';
    case 'ready_for_driver_pickup':
      return 'Ready for Driver Pickup';
    case 'pending_driver_receipt':
      return 'Pending Driver Receipt';
    case 'driver_received_order':
      return 'Driver Received Order';
    case 'assigned':
      return 'Assigned';
    case 'assigned_to_company':
      return 'Assigned to Company';
    case 'assigned_to_driver':
      return 'Assigned to Driver';
    case 'picked_up':
      return 'Picked Up';
    case 'picked_up_from_merchant':
      return 'Picked Up from Merchant';
    case 'in_transit':
      return 'In Transit';
    case 'in_transit_to_pickup_point':
      return 'In Transit to Pickup Point';
    case 'arrived_at_pickup_point':
      return 'Arrived at Pickup Point';
    case 'stored_at_pickup_point':
      return 'Stored at Pickup Point';
    case 'ready_for_customer_pickup':
      return 'Ready for Customer Pickup';
    case 'picked_up_by_customer':
      return 'Picked Up by Customer';
    case 'dropped_at_pickup_point':
      return 'Dropped at Pickup Point';
    case 'delivered':
    case 'completed':
      return 'Delivered';
    case 'delivery_failed':
    case 'failed':
      return 'Delivery Failed';
    case 'cancelled':
      return 'Cancelled';
    case 'rescheduled':
      return 'Rescheduled';
    case 'returning':
    case 'returning_to_store':
    case 'return_in_progress':
      return 'Returning to Merchant';
    case 'returned_to_store':
    case 'returned_to_merchant':
      return 'Returned to Merchant';
    case 'customer_not_available':
      return 'Customer Not Available';
    default:
      return s
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

Color _statusColor(String s) {
  final status = s.toLowerCase();

  if (status == 'delivered' ||
      status == 'completed' ||
      status == 'ready_for_customer_pickup' ||
      status == 'picked_up_by_customer' ||
      status == 'stored_at_pickup_point' ||
      status == 'dropped_at_pickup_point') {
    return _W.green;
  }

  if (status == 'delivery_failed' ||
      status == 'failed' ||
      status == 'cancelled' ||
      status == 'customer_not_available') {
    return _W.red;
  }

  if (status == 'returning' ||
      status == 'returning_to_store' ||
      status == 'return_in_progress' ||
      status == 'returned_to_store' ||
      status == 'returned_to_merchant' ||
      status == 'rescheduled') {
    return _W.amber;
  }

  if (status == 'assigned' ||
      status == 'assigned_to_company' ||
      status == 'assigned_to_driver' ||
      status == 'in_transit' ||
      status == 'in_transit_to_pickup_point' ||
      status == 'picked_up' ||
      status == 'picked_up_from_merchant' ||
      status == 'confirmed_by_merchant' ||
      status == 'ready_for_driver_pickup' ||
      status == 'pending_driver_receipt' ||
      status == 'driver_received_order' ||
      status == 'arrived_at_pickup_point') {
    return _W.blue;
  }

  return _W.slate;
}

Color _statusBg(String s) {
  final status = s.toLowerCase();

  if (status == 'delivered' ||
      status == 'completed' ||
      status == 'ready_for_customer_pickup' ||
      status == 'picked_up_by_customer' ||
      status == 'stored_at_pickup_point' ||
      status == 'dropped_at_pickup_point') {
    return _W.greenLt;
  }

  if (status == 'delivery_failed' ||
      status == 'failed' ||
      status == 'cancelled' ||
      status == 'customer_not_available') {
    return _W.redLt;
  }

  if (status == 'returning' ||
      status == 'returning_to_store' ||
      status == 'return_in_progress' ||
      status == 'returned_to_store' ||
      status == 'returned_to_merchant' ||
      status == 'rescheduled') {
    return _W.amberLt;
  }

  if (status == 'assigned' ||
      status == 'assigned_to_company' ||
      status == 'assigned_to_driver' ||
      status == 'in_transit' ||
      status == 'in_transit_to_pickup_point' ||
      status == 'picked_up' ||
      status == 'picked_up_from_merchant' ||
      status == 'confirmed_by_merchant' ||
      status == 'ready_for_driver_pickup' ||
      status == 'pending_driver_receipt' ||
      status == 'driver_received_order' ||
      status == 'arrived_at_pickup_point') {
    return _W.blueLt;
  }

  return _W.slateLt;
}