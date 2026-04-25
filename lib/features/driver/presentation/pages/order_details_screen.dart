import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wasle/core/ui/ui.dart';
import '../../data/driver_deliveries_repository.dart';
import '../../data/models/delivery_timeline_event.dart';
import '../../data/models/driver_order_details.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final DriverDeliveriesRepository _repository = DriverDeliveriesRepository();

  bool isLoading = true;
  bool isUpdating = false;
  bool isConfirmingPickup = false;
  bool isConfirmingDropoffAtPickup = false;
  String? errorText;
  DriverOrderDetails? details;

  bool get _isBusy =>
      isUpdating || isConfirmingPickup || isConfirmingDropoffAtPickup;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final data = await _repository.getOrderDetails(widget.orderId);

      if (!mounted) return;
      setState(() {
        details = data;
        isLoading = false;
        errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus, {String? successLabel}) async {
    if (details == null) return;

    try {
      setState(() {
        isUpdating = true;
      });

      await _repository.updateOrderStatus(
        orderId: widget.orderId,
        newStatus: newStatus,
      );

      if (!mounted) return;

      final normalized = _repository.workflowStatusFromOrderStatus(newStatus);
      final label = successLabel ?? _statusLabel(normalized);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status updated to $label')));

      await _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<void> _openLocationAction({
    required double? lat,
    required double? lng,
    required String label,
  }) async {
    if (lat == null || lng == null) return;

    final mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      final launched = await launchUrl(
        mapsUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open $label map.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open $label map: $e')));
    }
  }

  Future<void> _onTapWorkflowAction(String action) async {
    if (details == null || _isBusy) return;

    final currentStatus = details!.delivery.status.toLowerCase();
    final allowedActions = _repository.getAllowedWorkflowActions(currentStatus);
    if (!allowedActions.contains(action)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allowedActions.isEmpty
                ? 'This order is in a terminal state.'
                : 'Only the next valid action is allowed right now.',
          ),
        ),
      );
      return;
    }

    if (action == 'driver_received_order') {
      await _confirmPickupFlow();
      return;
    }

    if (action == 'dropped_at_pickup_point') {
      await _confirmDropoffAtPickupPointFlow();
      return;
    }

    final mappedStatus = _repository.mapWorkflowActionToOrderStatus(action);
    if (mappedStatus == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid workflow action.')));
      return;
    }

    final needsConfirmation = {
      'delivered',
      'failed',
      'rescheduled',
      'returned_to_store',
      'returning_to_store',
    }.contains(action);

    if (needsConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Confirm ${_statusLabel(action)}'),
          content: const Text(
            'This action moves the order forward and cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    await _updateStatus(action, successLabel: _statusLabel(action));
  }

  _WorkflowActionLayout _resolveActionLayout({
    required String workflowStatus,
    required List<String> allowedActions,
  }) {
    if (allowedActions.isEmpty) {
      return const _WorkflowActionLayout(
        primaryAction: null,
        secondaryActions: [],
      );
    }

    // Failed state is exception-only by product rule.
    if (workflowStatus == 'failed') {
      return _WorkflowActionLayout(
        primaryAction: null,
        secondaryActions: List<String>.from(allowedActions),
      );
    }

    String primaryAction = allowedActions.first;

    // In transit prioritizes successful completion.
    if (workflowStatus == 'in_transit' &&
        allowedActions.contains('delivered')) {
      primaryAction = 'delivered';
    }

    final secondary = allowedActions
        .where((action) => action != primaryAction)
        .toList();
    return _WorkflowActionLayout(
      primaryAction: primaryAction,
      secondaryActions: secondary,
    );
  }

  Future<Map<String, dynamic>?> _selectPickupPoint({
    required String title,
    required String subtitle,
    required String confirmLabel,
  }) async {
    List<Map<String, dynamic>> points = [];
    try {
      points = await _repository.getAvailablePickupPoints();
    } catch (_) {
      points = [];
    }

    if (!mounted) return null;
    if (points.isEmpty) return null;

    String selectedId = points.first['id'].toString();
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedPoint = points.firstWhere(
              (point) => point['id'].toString() == selectedId,
              orElse: () => points.first,
            );
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                top: AppSpacing.xl,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppTextStyles.heading2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: AppTextStyles.bodyMuted),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Point',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    items: points.map((point) {
                      final id = point['id'].toString();
                      final name = point['name']?.toString() ?? 'Pickup point';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        selectedId = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    selectedPoint['address_text']?.toString() ?? '-',
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: confirmLabel,
                    icon: Icons.check_circle_outline,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirm != true) return null;
    return points.firstWhere(
      (point) => point['id'].toString() == selectedId,
      orElse: () => points.first,
    );
  }

  Future<void> _confirmPickupFlow() async {
    if (details == null ||
        isConfirmingPickup ||
        isUpdating ||
        isConfirmingDropoffAtPickup) {
      return;
    }

    try {
      setState(() => isConfirmingPickup = true);
      final selectedPoint = await _selectPickupPoint(
        title: 'Confirm Pickup',
        subtitle: 'Select pickup point then confirm order handover.',
        confirmLabel: 'Confirm Pickup',
      );
      if (!mounted) return;

      if (selectedPoint == null) {
        final fallbackConfirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirm Pickup'),
            content: const Text('Confirm that you received the order?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        if (fallbackConfirm != true) return;
        await _updateStatus(
          'picked_up',
          successLabel: _statusLabel('driver_received_order'),
        );
        return;
      }

      await _repository.confirmPickupWithPoint(
        orderId: widget.orderId,
        pickupPointId: selectedPoint['id'].toString(),
        pickupPointName: selectedPoint['name']?.toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order received successfully')),
      );
      await _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to confirm pickup: $e')));
    } finally {
      if (mounted) {
        setState(() => isConfirmingPickup = false);
      }
    }
  }

  Future<void> _confirmDropoffAtPickupPointFlow() async {
    if (details == null ||
        isConfirmingDropoffAtPickup ||
        isUpdating ||
        isConfirmingPickup) {
      return;
    }

    try {
      setState(() => isConfirmingDropoffAtPickup = true);
      final selectedPoint = await _selectPickupPoint(
        title: 'Delivered To Pickup Point',
        subtitle: 'Choose the pickup point where the order was dropped.',
        confirmLabel: 'Confirm Dropoff',
      );
      if (!mounted) return;

      if (selectedPoint == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup point is required for this action.'),
          ),
        );
        return;
      }

      await _repository.confirmDropoffAtPickupPoint(
        orderId: widget.orderId,
        pickupPointId: selectedPoint['id'].toString(),
        pickupPointName: selectedPoint['name']?.toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order dropped at pickup point')),
      );
      await _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to drop at pickup point: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isConfirmingDropoffAtPickup = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (errorText != null || details == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load order',
          message: errorText ?? 'Unknown error',
          action: SecondaryButton(
            label: 'Try Again',
            isExpanded: false,
            onPressed: _loadDetails,
          ),
        ),
      );
    }

    final delivery = details!.delivery;
    final workflowStatus = _repository.workflowStatusFromOrderStatus(
      delivery.status,
    );
    final allowedWorkflowActions = _repository.getAllowedWorkflowActions(
      delivery.status,
    );
    final actionLayout = _resolveActionLayout(
      workflowStatus: workflowStatus,
      allowedActions: allowedWorkflowActions,
    );
    final hasPackageInfo =
        delivery.itemCount != null ||
        delivery.estimatedWeightKg != null ||
        delivery.estimatedVolumeCm3 != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            InfoCard(
              title: delivery.trackingCode,
              subtitle: delivery.merchantName,
              trailing: StatusChip(
                label: _statusLabel(delivery.status),
                tone: StatusChip.fromStatus(delivery.status),
              ),
              child: Text(
                'Order ID: ${delivery.orderId}',
                style: AppTextStyles.bodyMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            InfoCard(
              title: 'Pickup Information',
              subtitle: delivery.pickupPointName,
              leading: _iconBox(Icons.pin_drop_outlined),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(delivery.pickupAddress, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _coordinateLabel(delivery.pickupLat, delivery.pickupLng),
                    style: AppTextStyles.bodyMuted,
                  ),
                  if (details!.pickupOpeningHours != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Hours: ${details!.pickupOpeningHours}',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _mapButton(
                    actionLabel: 'Open Pickup Map',
                    missingLabel: 'Pickup location unavailable',
                    lat: delivery.pickupLat,
                    lng: delivery.pickupLng,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            InfoCard(
              title: 'Dropoff Information',
              subtitle: delivery.dropoffName ?? 'Dropoff location',
              leading: _iconBox(Icons.flag_outlined),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details!.dropoffAddress ??
                        delivery.dropoffAddress ??
                        'Not provided',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _coordinateLabel(details!.dropoffLat, details!.dropoffLng),
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _mapButton(
                    actionLabel: 'Open Dropoff Map',
                    missingLabel: 'Dropoff location unavailable',
                    lat: details!.dropoffLat,
                    lng: details!.dropoffLng,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            InfoCard(
              title: 'Customer Details',
              leading: _iconBox(Icons.person_outline_rounded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name: ${delivery.customerName}',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Phone: ${delivery.customerPhone}',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
            if (hasPackageInfo) ...[
              const SizedBox(height: AppSpacing.md),
              InfoCard(
                title: 'Package Information',
                leading: _iconBox(Icons.inventory_2_outlined),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (delivery.itemCount != null)
                      Text(
                        'Item count: ${delivery.itemCount}',
                        style: AppTextStyles.body,
                      ),
                    if (delivery.estimatedWeightKg != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Estimated weight: ${delivery.estimatedWeightKg!.toStringAsFixed(2)} kg',
                        style: AppTextStyles.body,
                      ),
                    ],
                    if (delivery.estimatedVolumeCm3 != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Estimated volume: ${delivery.estimatedVolumeCm3!.toStringAsFixed(0)} cm3',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (details!.orderNotes != null &&
                details!.orderNotes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              InfoCard(
                title: 'Order Notes',
                leading: _iconBox(Icons.notes_outlined),
                child: Text(details!.orderNotes!, style: AppTextStyles.body),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            InfoCard(
              title: 'Order Timeline',
              subtitle: 'Events from order_events',
              leading: _iconBox(Icons.timeline_outlined),
              child: details!.events.isEmpty
                  ? Text('No events found', style: AppTextStyles.bodyMuted)
                  : Column(
                      children: details!.events.map((event) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _EventRow(event: event),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            InfoCard(
              title: 'Update Status',
              subtitle: allowedWorkflowActions.isEmpty
                  ? 'No next action available from current state'
                  : 'Only valid next action(s) are shown',
              leading: _iconBox(Icons.update_rounded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current: ${_statusLabel(workflowStatus)}',
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (actionLayout.primaryAction != null)
                    PrimaryButton(
                      label: _statusLabel(actionLayout.primaryAction!),
                      icon: _actionIcon(actionLayout.primaryAction!),
                      isLoading: _isBusy,
                      onPressed: _isBusy
                          ? null
                          : () => _onTapWorkflowAction(
                              actionLayout.primaryAction!,
                            ),
                    ),
                  if (actionLayout.secondaryActions.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: actionLayout.secondaryActions.map((action) {
                        return _StatusActionButton(
                          label: _statusLabel(action),
                          enabled: !_isBusy,
                          tone: _toneForStatus(action),
                          onPressed: () => _onTapWorkflowAction(action),
                        );
                      }).toList(),
                    ),
                  ],
                  if (allowedWorkflowActions.isEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This order is already in a terminal state.',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: AppColors.primary),
    );
  }

  String _coordinateLabel(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return 'Location unavailable';
    }
    return 'Lat/Lng: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  Widget _mapButton({
    required String actionLabel,
    required String missingLabel,
    required double? lat,
    required double? lng,
  }) {
    final hasCoordinates = lat != null && lng != null;
    return SecondaryButton(
      label: hasCoordinates ? actionLabel : missingLabel,
      icon: Icons.map_outlined,
      onPressed: hasCoordinates
          ? () => _openLocationAction(lat: lat, lng: lng, label: actionLabel)
          : null,
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'created':
      case 'ready_for_driver_pickup':
      case 'assigned':
      case 'pending_driver_receipt':
        return 'Pending Driver Receipt';
      case 'driver_received_order':
      case 'picked_up':
        return 'Driver Received Order';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'dropped_at_pickup_point':
        return 'Drop At Pickup Point';
      case 'failed':
        return 'Delivery Failed';
      case 'rescheduled':
        return 'Reschedule';
      case 'returning_to_store':
        return 'Returning To Store';
      case 'returned_to_store':
        return 'Returned To Store';
    }
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'driver_received_order':
        return Icons.inventory_2_outlined;
      case 'in_transit':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'failed':
        return Icons.error_outline_rounded;
      case 'rescheduled':
        return Icons.event_repeat_outlined;
      case 'dropped_at_pickup_point':
        return Icons.storefront_outlined;
      case 'returning_to_store':
        return Icons.keyboard_return_rounded;
      case 'returned_to_store':
        return Icons.assignment_turned_in_outlined;
      default:
        return Icons.play_arrow_rounded;
    }
  }

  _ActionTone _toneForStatus(String status) {
    switch (status) {
      case 'delivered':
      case 'dropped_at_pickup_point':
      case 'returned_to_store':
        return _ActionTone.success;
      case 'failed':
        return _ActionTone.danger;
      default:
        return _ActionTone.primary;
    }
  }
}

class _EventRow extends StatelessWidget {
  final DeliveryTimelineEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final eventLabel = event.eventType
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');

    final dateText = event.createdAt.toLocal().toString();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 10, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eventLabel, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xxs),
              Text(dateText, style: AppTextStyles.bodyMuted),
              if (event.note != null && event.note!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(event.note!, style: AppTextStyles.body),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum _ActionTone { primary, success, danger }

class _WorkflowActionLayout {
  final String? primaryAction;
  final List<String> secondaryActions;

  const _WorkflowActionLayout({
    required this.primaryAction,
    required this.secondaryActions,
  });
}

class _StatusActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final _ActionTone tone;
  final VoidCallback onPressed;

  const _StatusActionButton({
    required this.label,
    required this.enabled,
    required this.tone,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForTone(tone);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: SizedBox(
        height: 42,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.surface,
            foregroundColor: palette.foreground,
            disabledForegroundColor: AppColors.textSecondary,
            side: BorderSide(
              color: enabled ? palette.border : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: AppTextStyles.button.copyWith(fontSize: 13),
          ),
          onPressed: enabled ? onPressed : null,
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  _ActionPalette _paletteForTone(_ActionTone tone) {
    switch (tone) {
      case _ActionTone.success:
        return const _ActionPalette(
          background: AppColors.successSoft,
          foreground: AppColors.success,
          border: Color(0xFFBEECCB),
        );
      case _ActionTone.danger:
        return const _ActionPalette(
          background: AppColors.dangerSoft,
          foreground: AppColors.danger,
          border: Color(0xFFFECACA),
        );
      case _ActionTone.primary:
        return const _ActionPalette(
          background: AppColors.primarySoft,
          foreground: AppColors.primary,
          border: Color(0xFFBCD3FF),
        );
    }
  }
}

class _ActionPalette {
  final Color background;
  final Color foreground;
  final Color border;

  const _ActionPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });
}
