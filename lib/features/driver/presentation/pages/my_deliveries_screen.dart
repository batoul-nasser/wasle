import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
import '../../data/driver_deliveries_repository.dart';
import '../../data/models/driver_delivery.dart';
import '../widgets/delivery_order_card.dart';
import 'order_details_screen.dart';

class MyDeliveriesScreen extends StatefulWidget {
  const MyDeliveriesScreen({super.key});

  @override
  State<MyDeliveriesScreen> createState() => _MyDeliveriesScreenState();
}

class _MyDeliveriesScreenState extends State<MyDeliveriesScreen> {
  final DriverDeliveriesRepository _repository = DriverDeliveriesRepository();

  DeliveryBucket _bucket = DeliveryBucket.active;
  String _selectedStatus = 'all';

  bool isLoading = true;
  String? errorText;
  List<DriverDelivery> deliveries = [];

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    try {
      final data = await _repository.getDriverDeliveries(
        bucket: _bucket,
        status: _selectedStatus,
      );

      if (!mounted) return;
      setState(() {
        deliveries = data;
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

  void _openOrderDetails(DriverDelivery delivery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orderId: delivery.orderId),
      ),
    ).then((_) => _loadDeliveries());
  }

  @override
  Widget build(BuildContext context) {
    final bucketStatuses = _bucket == DeliveryBucket.active
        ? DriverDeliveriesRepository.activeStatuses
        : DriverDeliveriesRepository.completedStatuses;
    final statusOptions = <String>['all', ...bucketStatuses];

    if (!statusOptions.contains(_selectedStatus)) {
      _selectedStatus = 'all';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
              ? EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load deliveries',
                  message: errorText!,
                  action: SecondaryButton(
                    label: 'Try Again',
                    isExpanded: false,
                    onPressed: _loadDeliveries,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDeliveries,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      const SectionHeader(
                        title: 'Assigned Orders',
                        subtitle: 'Only orders assigned to your driver account',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          ChoiceChip(
                            label: const Text('Active'),
                            selected: _bucket == DeliveryBucket.active,
                            onSelected: (_) {
                              setState(() {
                                _bucket = DeliveryBucket.active;
                                _selectedStatus = 'all';
                              });
                              _loadDeliveries();
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Completed'),
                            selected: _bucket == DeliveryBucket.completed,
                            onSelected: (_) {
                              setState(() {
                                _bucket = DeliveryBucket.completed;
                                _selectedStatus = 'all';
                              });
                              _loadDeliveries();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String>(
                        key: ValueKey('$_bucket-$_selectedStatus'),
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Filter by status',
                          prefixIcon: Icon(Icons.filter_alt_outlined),
                        ),
                        items: statusOptions.map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(_label(status)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedStatus = value;
                          });
                          _loadDeliveries();
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (deliveries.isEmpty)
                        const EmptyStateWidget(
                          icon: Icons.local_shipping_outlined,
                          title: 'No deliveries found',
                          message: 'No orders match the selected filters.',
                        )
                      else
                        ...deliveries.map((delivery) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: DeliveryOrderCard(
                              delivery: delivery,
                              onTap: () => _openOrderDetails(delivery),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }

  String _label(String value) {
    if (value == 'all') return 'All statuses';
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
