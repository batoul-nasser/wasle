import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/auth_service.dart';

class CompanyAssignOrdersScreen extends StatefulWidget {
  const CompanyAssignOrdersScreen({super.key});

  @override
  State<CompanyAssignOrdersScreen> createState() => _CompanyAssignOrdersScreenState();
}

class _CompanyAssignOrdersScreenState extends State<CompanyAssignOrdersScreen> {
  final AuthService _authService = AuthService();
  static const Set<String> _reassignableStatuses = {
    'created',
    'pending',
    'assigned',
    'pending_driver_receipt',
    'failed',
    'rescheduled',
    'ready_for_driver_pickup',
  };
  static const Set<String> _lockedStatuses = {
    'in_transit',
    'picked_up',
    'driver_received_order',
    'delivered',
    'cancelled',
    'dropped_at_pickup_point',
    'returning_to_store',
    'returned_to_store',
  };

  bool isLoading = true;
  bool isAssigning = false;
  String? errorText;
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> approvedDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final ordersData = await _authService.getCompanyAssignmentsOrders();
      final driversData = await _authService.getApprovedDriversForCurrentCompany();

      if (!mounted) return;
      setState(() {
        orders = ordersData;
        approvedDrivers = driversData;
        isLoading = false;
        errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorText = e.toString();
      });
    }
  }

  Future<void> _openAssignSheet(Map<String, dynamic> order) async {
    final pageContext = context;

    if (approvedDrivers.isEmpty) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('No approved drivers available')),
      );
      return;
    }

    String? selectedDriverId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                top: AppSpacing.xl,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Assign Driver', style: AppTextStyles.heading2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    order['tracking_code']?.toString() ?? order['order_id'].toString(),
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InfoCard(
                    title: 'Order Summary',
                    subtitle: order['merchant_name']?.toString() ?? 'Merchant',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pickup: ${order['pickup_name'] ?? '-'}',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          order['pickup_address']?.toString() ?? '-',
                          style: AppTextStyles.bodyMuted,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Dropoff: ${order['dropoff_address'] ?? '-'}',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Customer: ${order['customer_name'] ?? 'Customer'} (${order['customer_phone'] ?? '-'})',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDriverId,
                    decoration: const InputDecoration(
                      labelText: 'Choose Driver',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    hint: const Text('Select driver'),
                    items: approvedDrivers.map((driver) {
                      final id = driver['driver_id'].toString();
                      final name = driver['full_name']?.toString() ?? 'Driver';
                      final phone = driver['phone']?.toString() ?? '-';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text('$name ($phone)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedDriverId = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Confirm Assignment',
                    icon: Icons.check_circle_outline,
                    isLoading: isAssigning,
                    onPressed: selectedDriverId == null
                        ? null
                        : () async {
                            try {
                              setState(() => isAssigning = true);

                              await _authService.assignOrderToDriver(
                                orderId: order['order_id'].toString(),
                                driverId: selectedDriverId!,
                              );

                              if (!mounted) return;
                              Navigator.of(pageContext).pop();
                              ScaffoldMessenger.of(pageContext).showSnackBar(
                                const SnackBar(content: Text('Order assigned successfully')),
                              );
                              _loadData();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(pageContext).showSnackBar(
                                SnackBar(content: Text('Failed to assign: $e')),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => isAssigning = false);
                              }
                            }
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _unassignDriver(Map<String, dynamic> order) async {
    final pageContext = context;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unassign Driver'),
          content: Text(
            'Remove current driver from ${order['tracking_code'] ?? 'this order'}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unassign'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      setState(() => isAssigning = true);
      await _authService.unassignOrderFromDriver(orderId: order['order_id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('Driver unassigned successfully')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text('Failed to unassign: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isAssigning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasDriver(Map<String, dynamic> order) {
      final driverId = order['driver_id']?.toString();
      return driverId != null && driverId.isNotEmpty;
    }

    bool isLocked(Map<String, dynamic> order) {
      final status = order['status']?.toString().toLowerCase() ?? 'created';
      return _lockedStatuses.contains(status);
    }

    bool canReassign(Map<String, dynamic> order) {
      final status = order['status']?.toString().toLowerCase() ?? 'created';
      return _reassignableStatuses.contains(status) && !isLocked(order);
    }

    final unassignedOrders = orders.where((order) {
      return !hasDriver(order) && canReassign(order);
    }).toList();

    final assignedOrders = orders.where((order) {
      return hasDriver(order) && canReassign(order);
    }).toList();

    final lockedOrders = orders.where((order) {
      return isLocked(order);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Orders'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
              ? EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load orders',
                  message: errorText!,
                  action: SecondaryButton(
                    label: 'Try Again',
                    isExpanded: false,
                    onPressed: _loadData,
                  ),
                )
              : orders.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.inbox_outlined,
                      title: 'No company assignments',
                      message: 'Orders assigned to this delivery company will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        children: [
                          const SectionHeader(
                            title: 'Not Assigned Yet',
                            subtitle: 'Assign these orders to a delivery driver',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (unassignedOrders.isEmpty)
                            const InfoCard(
                              child: Text(
                                'All current orders already have assigned drivers.',
                                style: AppTextStyles.bodyMuted,
                              ),
                            )
                          else
                            ...unassignedOrders.map((order) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _OrderCard(
                                  order: order,
                                  onAssignTap: () => _openAssignSheet(order),
                                  onUnassignTap: null,
                                  assignEnabled: true,
                                ),
                              );
                            }),
                          const SizedBox(height: AppSpacing.lg),
                          const SectionHeader(
                            title: 'Already Assigned',
                            subtitle: 'Reassign if needed',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (assignedOrders.isEmpty)
                            const InfoCard(
                              child: Text(
                                'No assigned orders found yet.',
                                style: AppTextStyles.bodyMuted,
                              ),
                            )
                          else
                            ...assignedOrders.map((order) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _OrderCard(
                                  order: order,
                                  onAssignTap: () => _openAssignSheet(order),
                                  onUnassignTap: () => _unassignDriver(order),
                                  assignEnabled: true,
                                ),
                              );
                            }),
                          const SizedBox(height: AppSpacing.lg),
                          const SectionHeader(
                            title: 'Locked (In Progress / Closed)',
                            subtitle: 'These orders cannot be assigned anymore',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (lockedOrders.isEmpty)
                            const InfoCard(
                              child: Text(
                                'No locked orders.',
                                style: AppTextStyles.bodyMuted,
                              ),
                            )
                          else
                            ...lockedOrders.map((order) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _OrderCard(
                                  order: order,
                                  onAssignTap: () {},
                                  onUnassignTap: null,
                                  assignEnabled: false,
                                ),
                              );
                            }),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAssignTap;
  final VoidCallback? onUnassignTap;
  final bool assignEnabled;

  const _OrderCard({
    required this.order,
    required this.onAssignTap,
    required this.onUnassignTap,
    required this.assignEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final rawStatus = (order['status']?.toString() ?? 'created').toLowerCase();
    final driverId = order['driver_id']?.toString();
    final hasDriver = driverId != null && driverId.isNotEmpty;
    final acceptedAt = order['accepted_at']?.toString();
    final waitingForDriverResponse = hasDriver && (acceptedAt == null || acceptedAt.isEmpty);
    final displayStatus = rawStatus;

    return InfoCard(
      title: order['tracking_code']?.toString() ?? 'Order',
      subtitle: order['merchant_name']?.toString() ?? 'Merchant',
      trailing: StatusChip(
        label: _statusLabel(displayStatus),
        tone: StatusChip.fromStatus(displayStatus),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${order['pickup_name'] ?? 'Pickup point'} - ${order['pickup_address'] ?? '-'}',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasDriver
                ? waitingForDriverResponse
                    ? 'Driver: ${order['driver_name'] ?? 'Assigned'} (${order['driver_phone'] ?? '-'}) - awaiting response'
                    : 'Driver: ${order['driver_name'] ?? 'Assigned'} (${order['driver_phone'] ?? '-'})'
                : 'Driver: Not assigned',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Customer: ${order['customer_name'] ?? 'Customer'}',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: assignEnabled
                ? (hasDriver ? 'Reassign Driver' : 'Assign Driver')
                : 'Order Locked',
            icon: assignEnabled
                ? Icons.person_add_alt_1_rounded
                : Icons.lock_outline_rounded,
            onPressed: assignEnabled ? onAssignTap : null,
          ),
          if (assignEnabled && hasDriver && onUnassignTap != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Unassign Driver',
              icon: Icons.person_remove_alt_1_rounded,
              onPressed: onUnassignTap,
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

