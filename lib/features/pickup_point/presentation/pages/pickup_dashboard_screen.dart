import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/pickup_point/data/pickup_point_repository.dart';
import 'package:wasle/features/pickup_point/presentation/pages/pickup_point_dashboard_screen.dart';

class PickupDashboardScreen extends StatefulWidget {
  const PickupDashboardScreen({super.key});

  @override
  State<PickupDashboardScreen> createState() => _PickupDashboardScreenState();
}

class _PickupDashboardScreenState extends State<PickupDashboardScreen> {
  final PickupPointRepository _repository = PickupPointRepository();
  final TextEditingController searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool isLoading = true;
  bool isSubmitting = false;
  String? errorText;

  Map<String, dynamic>? pickupPointData;
  List<Map<String, dynamic>> parcels = [];
  String selectedFilter = 'all';
  String? selectedPickupPointId;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;

  bool get _isDemoMode => selectedPickupPointId == 'demo-pickup-point';

  String _normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');

  String _vehicleLabel(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.contains('moto') || text.contains('bike')) return 'Motorcycle';
    if (text.contains('car')) return 'Car';
    return value == null || value.trim().isEmpty ? 'Unknown vehicle' : value;
  }

  IconData _vehicleIcon(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.contains('moto') || text.contains('bike'))
      return Icons.two_wheeler_rounded;
    return Icons.directions_car_filled_rounded;
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    try {
      setState(() { isLoading = true; errorText = null; });
      final pickupPoint = await _repository.getMyPickupPoint();
      if (pickupPoint == null) {
        if (!mounted) return;
        _loadDemoData(message: 'No pickup point linked. Showing demo data.');
        return;
      }
      final pickupPointId = pickupPoint['id']?.toString();
      if (pickupPointId == null || pickupPointId.isEmpty) {
        if (!mounted) return;
        _loadDemoData(message: 'Pickup point ID missing. Showing demo data.');
        return;
      }
      final parcelRows = await _repository.getPickupPointParcels(
          pickupPointId: pickupPointId);
      if (!mounted) return;
      setState(() {
        selectedPickupPointId = pickupPointId;
        pickupPointData = pickupPoint;
        parcels = parcelRows;
        isLoading = false;
        errorText = null;
      });
      _subscribeToRealtime(pickupPointId);
    } catch (e) {
      if (!mounted) return;
      _loadDemoData(message: 'Live data unavailable.\n$e');
    }
  }

  void _loadDemoData({String? message}) {
    setState(() {
      selectedPickupPointId = 'demo-pickup-point';
      pickupPointData = {
        'id': 'demo-pickup-point',
        'name': 'Hamra Pickup Point',
        'address_text': 'Beirut, Hamra Main Street',
        'status': 'active',
      };
      parcels = [
        {'order_id': 'ORD-1001', 'status': 'dropped_at_pickup_point', 'customer_name': 'Ahmad', 'customer_phone': '+961 70 111 111', 'delivery_company_name': 'Fast Drop', 'delivery_driver_name': 'Khaled', 'delivery_driver_phone': '+961 71 222 333', 'delivery_vehicle_type': 'motorcycle', 'delivery_assigned_at': DateTime.now().toIso8601String()},
        {'order_id': 'ORD-1002', 'status': 'received_at_pickup_point', 'customer_name': 'Sara', 'customer_phone': '+961 70 222 222', 'delivery_company_name': 'Quick Express', 'delivery_driver_name': 'Rami', 'delivery_driver_phone': '+961 76 444 555', 'delivery_vehicle_type': 'car', 'delivery_assigned_at': DateTime.now().toIso8601String()},
        {'order_id': 'ORD-1003', 'status': 'ready_for_customer_pickup', 'customer_name': 'Maya', 'customer_phone': '+961 70 333 333', 'delivery_company_name': 'Quick Express', 'delivery_driver_name': 'Jad', 'delivery_driver_phone': '+961 81 123 456', 'delivery_vehicle_type': 'motorcycle', 'delivery_assigned_at': DateTime.now().toIso8601String()},
        {'order_id': 'ORD-1004', 'status': 'picked_up', 'customer_name': 'Omar', 'customer_phone': '+961 70 444 444', 'delivery_company_name': 'Fast Drop', 'delivery_driver_name': 'Nadim', 'delivery_driver_phone': '+961 03 555 777', 'delivery_vehicle_type': 'car', 'delivery_assigned_at': DateTime.now().toIso8601String()},
      ];
      isLoading = false;
      errorText = message;
    });
  }

  void _subscribeToRealtime(String pickupPointId) {
    _ordersSubscription?.cancel();
    _ordersSubscription =
        _repository.watchPickupPointOrders(pickupPointId).listen((_) async {
      final refreshed = await _repository.getPickupPointParcels(
          pickupPointId: pickupPointId);
      if (!mounted) return;
      setState(() { parcels = refreshed; });
    });
  }

  Future<void> _refreshParcels() async {
    final pickupPointId = selectedPickupPointId;
    if (pickupPointId == null || pickupPointId.isEmpty) return;
    final refreshed = await _repository.getPickupPointParcels(
        pickupPointId: pickupPointId);
    if (!mounted) return;
    setState(() { parcels = refreshed; });
  }

  Future<void> _updateStatus({required String orderId, required String newStatus, required String successMessage}) async {
    if (_isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo mode only.')));
      return;
    }
    try {
      setState(() => isSubmitting = true);
      await _repository.updateParcelStatus(orderId: orderId, newStatus: newStatus);
      await _refreshParcels();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _reportIssue(String orderId) async {
    if (_isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo mode only.')));
      return;
    }
    final pickupPointId = selectedPickupPointId;
    if (pickupPointId == null) return;
    final descriptionController = TextEditingController();
    String issueType = 'damaged';
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    final imagePicker = ImagePicker();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickImage() async {
            final file = await imagePicker.pickImage(
                source: ImageSource.gallery, imageQuality: 70);
            if (file == null) return;
            final bytes = await file.readAsBytes();
            setDialogState(() { selectedImageBytes = bytes; selectedImageName = file.name; });
          }
          return AlertDialog(
            title: const Text('Report Parcel Issue'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: issueType,
                  decoration: const InputDecoration(labelText: 'Issue Type'),
                  items: const [
                    DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                    DropdownMenuItem(value: 'missing', child: Text('Missing')),
                    DropdownMenuItem(value: 'delayed', child: Text('Delayed')),
                    DropdownMenuItem(value: 'wrong_parcel', child: Text('Wrong Parcel')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) { if (value != null) setDialogState(() => issueType = value); },
                ),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: pickImage, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Add Photo')),
                if (selectedImageName != null) ...[const SizedBox(height: 8), Text(selectedImageName!, style: AppTextStyles.bodyMuted)],
                if (selectedImageBytes != null) ...[const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(selectedImageBytes!, height: 140, width: double.infinity, fit: BoxFit.cover))],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    String? photoUrl;
                    if (selectedImageBytes != null) {
                      photoUrl = await _repository.uploadIssuePhoto(orderId: orderId, bytes: selectedImageBytes!, fileExtension: 'jpg');
                    }
                    await _repository.reportParcelIssue(orderId: orderId, pickupPointId: pickupPointId, issueType: issueType, description: descriptionController.text.trim(), photoUrl: photoUrl);
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    await _refreshParcels();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Issue reported for $orderId')));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
    descriptionController.dispose();
  }

  List<Map<String, dynamic>> _filteredParcels() {
    final query = searchController.text.trim().toLowerCase();
    final normalizedQuery = _normalizePhone(searchController.text.trim());
    return parcels.where((parcel) {
      final matchesSearch = query.isEmpty ||
          (parcel['order_id']?.toString().toLowerCase() ?? '').contains(query) ||
          (parcel['customer_name']?.toString().toLowerCase() ?? '').contains(query) ||
          (parcel['customer_phone']?.toString().toLowerCase() ?? '').contains(query) ||
          (parcel['delivery_company_name']?.toString().toLowerCase() ?? '').contains(query) ||
          (parcel['delivery_driver_name']?.toString().toLowerCase() ?? '').contains(query) ||
          (normalizedQuery.isNotEmpty && _normalizePhone(parcel['customer_phone']?.toString() ?? '').contains(normalizedQuery));
      final matchesFilter = selectedFilter == 'all' || parcel['status']?.toString() == selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  String _formatStatusLabel(String status) => status.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  Widget _buildFilterChip(String value, String label) => ChoiceChip(
    label: Text(label),
    selected: selectedFilter == value,
    onSelected: (_) => setState(() => selectedFilter = value),
  );

  List<Widget> _buildParcelActions(Map<String, dynamic> parcel) {
    final status = parcel['status']?.toString() ?? '';
    final orderId = parcel['order_id']?.toString() ?? '';
    final actions = <Widget>[];
    if (status == 'dropped_at_pickup_point') {
      actions.add(OutlinedButton.icon(onPressed: isSubmitting ? null : () => _updateStatus(orderId: orderId, newStatus: 'received_at_pickup_point', successMessage: '$orderId marked as received'), icon: const Icon(Icons.move_to_inbox_outlined), label: const Text('Mark Received')));
    }
    if (status == 'received_at_pickup_point' || status == 'dropped_at_pickup_point') {
      actions.add(OutlinedButton.icon(onPressed: isSubmitting ? null : () => _updateStatus(orderId: orderId, newStatus: 'ready_for_customer_pickup', successMessage: '$orderId marked ready'), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Mark Ready')));
    }
    if (status == 'ready_for_customer_pickup') {
      actions.add(OutlinedButton.icon(onPressed: isSubmitting ? null : () => _updateStatus(orderId: orderId, newStatus: 'picked_up', successMessage: '$orderId marked as picked up'), icon: const Icon(Icons.check_circle_outline), label: const Text('Mark Picked Up')));
    }
    if (status != 'picked_up') {
      actions.add(OutlinedButton.icon(onPressed: isSubmitting ? null : () => _reportIssue(orderId), icon: const Icon(Icons.error_outline_rounded), label: const Text('Report Issue')));
    }
    return actions;
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: (color ?? AppColors.surfaceMuted).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppTextStyles.caption), const SizedBox(height: 2), Text(value, style: AppTextStyles.body)])),
      ]),
    );
  }

  Widget _buildCustomerInfo(Map<String, dynamic> parcel) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Customer Info', style: AppTextStyles.title),
    const SizedBox(height: AppSpacing.sm),
    _buildInfoTile(icon: Icons.person_outline, label: 'Customer Name', value: parcel['customer_name']?.toString() ?? 'Customer'),
    const SizedBox(height: AppSpacing.xs),
    _buildInfoTile(icon: Icons.phone_outlined, label: 'Customer Phone', value: parcel['customer_phone']?.toString() ?? '-'),
  ]);

  Widget _buildDeliveryInfo(Map<String, dynamic> parcel) {
    final assignedAt = parcel['delivery_assigned_at']?.toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Delivery Info', style: AppTextStyles.title),
      const SizedBox(height: AppSpacing.sm),
      _buildInfoTile(icon: Icons.business_outlined, label: 'Delivery Company', value: parcel['delivery_company_name']?.toString() ?? 'No company assigned', color: AppColors.info),
      const SizedBox(height: AppSpacing.xs),
      _buildInfoTile(icon: Icons.badge_outlined, label: 'Driver Name', value: parcel['delivery_driver_name']?.toString() ?? 'No driver assigned', color: AppColors.success),
      const SizedBox(height: AppSpacing.xs),
      _buildInfoTile(icon: Icons.phone_in_talk_outlined, label: 'Driver Phone', value: parcel['delivery_driver_phone']?.toString() ?? '-', color: AppColors.success),
      const SizedBox(height: AppSpacing.xs),
      _buildInfoTile(icon: _vehicleIcon(parcel['delivery_vehicle_type']?.toString()), label: 'Vehicle Type', value: _vehicleLabel(parcel['delivery_vehicle_type']?.toString()), color: AppColors.warning),
      const SizedBox(height: AppSpacing.xs),
      _buildInfoTile(icon: Icons.local_shipping_outlined, label: 'Delivery Status', value: assignedAt == null || assignedAt.isEmpty ? 'Not available' : 'Assigned', color: AppColors.primary),
    ]);
  }

  Widget _buildParcelsTab() {
    final filteredParcels = _filteredParcels();
    final pickupName = pickupPointData?['name']?.toString() ?? 'Pickup Point';
    final ownerName = pickupPointData?['owner_name']?.toString() ?? 'Owner';
    final address = pickupPointData?['address_text']?.toString() ?? 'No address';
    final pickupStatus = pickupPointData?['status']?.toString() ?? 'inactive';
    final workingHours = '${pickupPointData?['opens_at'] ?? '-'} - ${pickupPointData?['closes_at'] ?? '-'}';

    final totalCount = parcels.length;
    final arrivedCount = parcels.where((p) => p['status'] == 'dropped_at_pickup_point').length;
    final receivedCount = parcels.where((p) => p['status'] == 'received_at_pickup_point').length;
    final readyCount = parcels.where((p) => p['status'] == 'ready_for_customer_pickup').length;
    final pickedUpCount = parcels.where((p) => p['status'] == 'picked_up').length;
    final issueCount = parcels.where((p) => p['status'] == 'issue_reported').length;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          if (errorText != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(16)),
              child: Text(errorText!, style: AppTextStyles.bodyMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Hero card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x331D4ED8), blurRadius: 24, offset: Offset(0, 14))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PICKUP POINT', style: AppTextStyles.label.copyWith(color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.8)),
              const SizedBox(height: AppSpacing.xs),
              Text(pickupName, style: AppTextStyles.heading1.copyWith(color: Colors.white)),
              const SizedBox(height: AppSpacing.xxs),
              Text('Owner: $ownerName', style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.96))),
              const SizedBox(height: AppSpacing.xxs),
              Text(address, style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.92))),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                _HeroChip(label: pickupStatus),
                _HeroChip(label: workingHours),
              ]),
            ]),
          ),
          // Stats grid
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Parcel Overview', subtitle: 'Quick summary of pickup point activity'),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: AppSpacing.md, mainAxisSpacing: AppSpacing.md, childAspectRatio: 1.2,
            children: [
              DashboardStatCard(icon: Icons.inventory_2_outlined, value: '$totalCount', label: 'Total Parcels'),
              DashboardStatCard(icon: Icons.move_to_inbox_outlined, value: '$arrivedCount', label: 'Arrived', accentColor: AppColors.warning, accentSoftColor: AppColors.warningSoft),
              DashboardStatCard(icon: Icons.inventory_outlined, value: '$receivedCount', label: 'Received', accentColor: AppColors.info, accentSoftColor: AppColors.infoSoft),
              DashboardStatCard(icon: Icons.local_shipping_outlined, value: '$readyCount', label: 'Ready Pickup', accentColor: AppColors.success, accentSoftColor: AppColors.successSoft),
              DashboardStatCard(icon: Icons.check_circle_outline, value: '$pickedUpCount', label: 'Picked Up', accentColor: AppColors.primary, accentSoftColor: AppColors.primarySoft),
              DashboardStatCard(icon: Icons.error_outline_rounded, value: '$issueCount', label: 'Issues', accentColor: AppColors.danger, accentSoftColor: AppColors.dangerSoft),
            ],
          ),
          // Search
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search by order, customer, driver, or phone',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
            _buildFilterChip('all', 'All'),
            _buildFilterChip('dropped_at_pickup_point', 'Arrived'),
            _buildFilterChip('received_at_pickup_point', 'Received'),
            _buildFilterChip('ready_for_customer_pickup', 'Ready'),
            _buildFilterChip('picked_up', 'Picked Up'),
            _buildFilterChip('issue_reported', 'Issues'),
          ]),
          // Parcels list
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Recent Parcels', subtitle: 'Manage incoming and ready parcels'),
          const SizedBox(height: AppSpacing.md),
          if (filteredParcels.isEmpty)
            const EmptyStateWidget(icon: Icons.inbox_outlined, title: 'No parcels found', message: 'Try another search or filter.')
          else
            ...filteredParcels.map((parcel) => Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.local_shipping_outlined)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(parcel['order_id']?.toString() ?? 'Order', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.xxs),
                      Text('${parcel['customer_name'] ?? 'Customer'} \u2022 ${parcel['customer_phone'] ?? '-'}', style: AppTextStyles.bodyMuted),
                    ])),
                    const SizedBox(width: AppSpacing.sm),
                    StatusChip(label: _formatStatusLabel(parcel['status']?.toString() ?? 'unknown'), tone: StatusChip.fromStatus(parcel['status']?.toString())),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(builder: (context, constraints) {
                    final isSmall = constraints.maxWidth < 700;
                    if (isSmall) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildCustomerInfo(parcel), const SizedBox(height: AppSpacing.md), _buildDeliveryInfo(parcel)]);
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _buildCustomerInfo(parcel)), const SizedBox(width: AppSpacing.md), Expanded(child: _buildDeliveryInfo(parcel))]);
                  }),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: _buildParcelActions(parcel)),
                ]),
              ),
            )),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: isSubmitting ? 'Updating...' : 'Refresh Dashboard', icon: Icons.refresh_rounded, onPressed: isSubmitting ? null : _loadDashboard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pickup Point'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.payments_outlined), text: 'Cash Payments'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Parcels'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  const PickupPointDashboardScreen(),
                  _buildParcelsTab(),
                ],
              ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTextStyles.label.copyWith(color: Colors.white)),
    );
  }
}