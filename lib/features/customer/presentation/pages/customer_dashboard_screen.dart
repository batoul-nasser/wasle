// File: lib/features/customer/presentation/pages/customer_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/ui/ui.dart';
import 'track_my_order_page.dart';
import 'payment_method_page.dart';
import 'pickup_point_page.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorText;
  String _userName = 'Customer';
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _latestOrder;
  Map<String, dynamic>? _latestPayment;
  Map<String, dynamic>? _pickupPoint;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });

      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorText = 'Not logged in';
        });
        return;
      }

      // Load profile
      final profile = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      _userName = profile?['full_name']?.toString() ?? 'Customer';

      // Load customer orders (orders tied to customer_profile_id)
      final ordersRaw = await _client
          .from('orders')
          .select('id, tracking_code, status, created_at, pickup_point_id')
          .eq('customer_profile_id', user.id)
          .order('created_at', ascending: false)
          .limit(10);

      _orders = List<Map<String, dynamic>>.from(ordersRaw);

      if (_orders.isNotEmpty) {
        _latestOrder = _orders.first;
        final orderId = _latestOrder!['id'].toString();

        // Load payment for latest order
        final paymentRaw = await _client
            .from('payments')
            .select('status, method, amount')
            .eq('order_id', orderId)
            .maybeSingle();
        _latestPayment = paymentRaw;

        // Load pickup point if linked
        final ppId = _latestOrder!['pickup_point_id']?.toString();
        if (ppId != null && ppId.isNotEmpty) {
          final ppRaw = await _client
              .from('pickup_points')
              .select('name, address_text, phone')
              .eq('id', ppId)
              .maybeSingle();
          _pickupPoint = ppRaw;
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = e.toString();
      });
    }
  }

  Future<void> _logout() async {
    await _client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (_) => false);
  }

  String _formatStatus(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Color _statusColor(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'delivered':
      case 'dropped_at_pickup_point':
        return AppColors.success;
      case 'in_transit':
      case 'picked_up':
      case 'driver_received_order':
        return AppColors.info;
      case 'assigned':
      case 'pending_driver_receipt':
      case 'created':
      case 'pending':
        return AppColors.warning;
      case 'failed':
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _orders
        .where(
          (o) => !{
            'delivered',
            'cancelled',
            'returned_to_store',
          }.contains(o['status']?.toString().toLowerCase()),
        )
        .length;
    final completedCount = _orders
        .where((o) => o['status']?.toString().toLowerCase() == 'delivered')
        .length;

    final orderStatus = _latestOrder?['status']?.toString();
    final trackingCode =
        _latestOrder?['tracking_code']?.toString() ??
        _latestOrder?['id']?.toString() ??
        '-';
    final paymentStatus = _latestPayment?['status']?.toString() ?? 'pending';
    final paymentMethod = _latestPayment?['method']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
          ? EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Could not load dashboard',
              message: _errorText!,
              action: SecondaryButton(
                label: 'Try Again',
                isExpanded: false,
                onPressed: _loadData,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  // Hero card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUSTOMER PORTAL',
                          style: AppTextStyles.label.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Welcome, $_userName!',
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Track your orders, payment, and pickup info.',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Stats
                  const SectionHeader(title: 'Order Summary'),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.inventory_2_outlined,
                          value: '${_orders.length}',
                          label: 'Total Orders',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.local_shipping_outlined,
                          value: '$activeCount',
                          label: 'Active',
                          accentColor: AppColors.warning,
                          accentSoftColor: AppColors.warningSoft,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.check_circle_outline,
                          value: '$completedCount',
                          label: 'Delivered',
                          accentColor: AppColors.success,
                          accentSoftColor: AppColors.successSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Latest order
                  if (_latestOrder != null) ...[
                    const SectionHeader(
                      title: 'Latest Order',
                      subtitle: 'Real-time status from the platform',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InfoCard(
                      title: 'Order #$trackingCode',
                      subtitle: 'Status',
                      trailing: StatusChip(
                        label: _formatStatus(orderStatus),
                        tone: StatusChip.fromStatus(orderStatus),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.payments_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Payment: ${_formatStatus(paymentMethod)} — ',
                                style: AppTextStyles.bodyMuted,
                              ),
                              StatusChip(
                                label: _formatStatus(paymentStatus),
                                tone: paymentStatus == 'paid'
                                    ? StatusChipTone.success
                                    : StatusChipTone.warning,
                              ),
                            ],
                          ),
                          if (_pickupPoint != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.store_outlined,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    _pickupPoint!['name']?.toString() ??
                                        'Pickup Point',
                                    style: AppTextStyles.body,
                                  ),
                                ),
                              ],
                            ),
                            if (_pickupPoint!['address_text'] != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Padding(
                                padding: const EdgeInsets.only(left: 22),
                                child: Text(
                                  _pickupPoint!['address_text'].toString(),
                                  style: AppTextStyles.bodyMuted,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ] else ...[
                    const EmptyStateWidget(
                      icon: Icons.inbox_outlined,
                      title: 'No orders yet',
                      message: 'Your orders will appear here once placed.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Quick actions
                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Track My Order',
                    icon: Icons.location_searching_outlined,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrackMyOrderPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Payment Method',
                    icon: Icons.payments_outlined,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PaymentMethodPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Pickup Point Details',
                    icon: Icons.store_outlined,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PickupPointPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}
