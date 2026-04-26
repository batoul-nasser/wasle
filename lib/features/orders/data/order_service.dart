import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/services/payment_service.dart';
import 'package:wasle/core/services/supabase_service.dart';
import 'package:wasle/features/payment/data/payment_model.dart';

class OrdersService {
  SupabaseClient get _db => SupabaseService.client;

  Future<List<Map<String, dynamic>>> getOrders() async {
    final merchantId = await _requireCurrentMerchantId();

    final rows = await _db
        .from('orders')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);

    final orders = List<Map<String, dynamic>>.from(rows);
    await _attachPayments(orders);
    return orders;
  }

  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    if (orderId.trim().isEmpty) return null;

    final merchantId = await _requireCurrentMerchantId();
    final row = await _db
        .from('orders')
        .select()
        .eq('id', orderId)
        .eq('merchant_id', merchantId)
        .maybeSingle();

    if (row == null) return null;

    final order = Map<String, dynamic>.from(row);
    await _attachPayments([order]);
    return order;
  }

  Future<List<Map<String, dynamic>>> getOrderEvents(String orderId) async {
    if (orderId.trim().isEmpty) return [];

    final order = await getOrderById(orderId);
    if (order == null) return [];

    final rows = await _db
        .from('order_events')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String?> getCompanyNameById(String companyId) async {
    if (companyId.trim().isEmpty) return null;

    final row = await _db
        .from('delivery_companies')
        .select('name')
        .eq('id', companyId)
        .maybeSingle();

    return row?['name']?.toString();
  }

  Future<void> requestCancellation({
    required String orderId,
    required String reason,
  }) async {
    if (orderId.trim().isEmpty) {
      throw Exception('Order ID is missing.');
    }

    final merchantId = await _requireCurrentMerchantId();
    final userId = _db.auth.currentUser?.id;
    final now = DateTime.now().toUtc().toIso8601String();

    await _db
        .from('orders')
        .update({
          'status': 'cancelled',
          'notes': 'Cancellation requested: ${reason.trim()}',
          'updated_at': now,
        })
        .eq('id', orderId)
        .eq('merchant_id', merchantId);

    await _db.from('order_events').insert({
      'order_id': orderId,
      'event_type': 'cancelled',
      if (userId != null && userId.isNotEmpty) 'created_by': userId,
      'note': 'Reason: ${reason.trim()}',
      'created_at': now,
    });
  }

  Future<List<Map<String, String>>> loadAvailablePickupPoints() async {
    final merchantId = await _requireCurrentMerchantId();

    final rows = await _db
        .from('pickup_points')
        .select('id, name, address_text')
        .eq('merchant_id', merchantId)
        .eq('is_active', true)
        .order('name');

    return List<Map<String, dynamic>>.from(rows)
        .map(
          (row) => {
            'id': row['id']?.toString() ?? '',
            'name': row['name']?.toString() ?? 'Pickup Point',
            'address': row['address_text']?.toString() ?? '',
          },
        )
        .where((row) => row['id']!.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, String>>> loadAvailableDeliveryCompanies() async {
    final merchantId = await _requireCurrentMerchantId();

    try {
      final mappingRows = await _db
          .from('merchant_delivery_companies')
          .select('company_id')
          .eq('merchant_id', merchantId)
          .eq('is_active', true);

      final companyIds = List<Map<String, dynamic>>.from(mappingRows)
          .map((row) => row['company_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (companyIds.isEmpty) return [];

      final companyRows = await _db
          .from('delivery_companies')
          .select('id, name')
          .inFilter('id', companyIds);

      return _companyOptionsFromRows(companyRows);
    } catch (_) {
      final companyRows = await _db
          .from('delivery_companies')
          .select('id, name')
          .order('name');
      return _companyOptionsFromRows(companyRows);
    }
  }

  Future<Map<String, dynamic>> createOrder({
    required String customerName,
    required String customerPhone,
    required String? customerEmail,
    required String address,
    required String pickupMethod,
    required double codAmount,
    String? notes,
    String? preferredTimeWindow,
    String? pickupPointId,
    String? deliveryCompanyId,
  }) async {
    final merchantId = await _requireCurrentMerchantId();
    final noteParts = <String>[
      'Pickup method: $pickupMethod',
      if (preferredTimeWindow != null && preferredTimeWindow.trim().isNotEmpty)
        'Preferred time window: ${preferredTimeWindow.trim()}',
      if (notes != null && notes.trim().isNotEmpty) notes.trim(),
    ];

    return PaymentService().createOrderWithPayment(
      merchantId: merchantId,
      branchId: null,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      address: address,
      amount: codAmount,
      paymentMethod: PaymentMethod.cashAtPickup,
      pickupPointId: pickupPointId,
      deliveryCompanyId: deliveryCompanyId,
      notes: noteParts.isEmpty ? null : noteParts.join('\n'),
    );
  }

  Future<String> _requireCurrentMerchantId() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final row = await _db
        .from('merchant_users')
        .select('merchant_id')
        .eq('profile_id', user.id)
        .maybeSingle();

    final merchantId = row?['merchant_id']?.toString();
    if (merchantId == null || merchantId.isEmpty) {
      throw Exception('Merchant profile not found. Please contact support.');
    }

    return merchantId;
  }

  Future<void> _attachPayments(List<Map<String, dynamic>> orders) async {
    final orderIds = orders
        .map((order) => order['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (orderIds.isEmpty) return;

    try {
      final rows = await _db
          .from('payments')
          .select()
          .inFilter('order_id', orderIds);

      final paymentsByOrderId = {
        for (final row in List<Map<String, dynamic>>.from(rows))
          if (row['order_id'] != null) row['order_id'].toString(): row,
      };

      for (final order in orders) {
        final payment = paymentsByOrderId[order['id']?.toString()];
        if (payment == null) continue;
        order['_payment'] = payment;
        order['payment_method'] = payment['method'];
        order['payment_status'] = payment['status'];
        order['payment_amount'] = payment['amount'];
      }
    } catch (_) {
      for (final order in orders) {
        order['_payment'] = null;
      }
    }
  }
  Future<Map<String, String>?> getPickupPointById(String pickupPointId) async {
  if (pickupPointId.trim().isEmpty) return null;

  final merchantId = await _requireCurrentMerchantId();

  final row = await _db
      .from('pickup_points')
      .select('id, name, address_text')
      .eq('id', pickupPointId)
      .eq('merchant_id', merchantId)
      .maybeSingle();

  if (row == null) return null;

  return {
    'id': row['id']?.toString() ?? '',
    'name': row['name']?.toString() ?? 'Pickup Point',
    'address': row['address_text']?.toString() ?? '',
  };
}

  List<Map<String, String>> _companyOptionsFromRows(Object? rows) {
    return List<Map<String, dynamic>>.from(rows as List)
        .map(
          (row) => {
            'id': row['id']?.toString() ?? '',
            'name': row['name']?.toString() ?? 'Delivery Company',
          },
        )
        .where((row) => row['id']!.isNotEmpty)
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }
}
