import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class PickupPointRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getMyPickupPoint() async {
  final user = _client.auth.currentUser;
  if (user == null) return null;

  // Check pickup_point_operators first (signup flow writes here)
  final link = await _client
      .from('pickup_point_operators')
      .select('pickup_point_id')
      .eq('profile_id', user.id)
      .maybeSingle();

  if (link != null) {
    final ppId = link['pickup_point_id'].toString();
    final row = await _client
        .from('pickup_points')
        .select(
          'id, name, owner_name, address_text, phone, email, city, area, '
          'image_url, opens_at, closes_at, opening_hours, preferred_payment_method, '
          'payment_handling_method, working_days, max_orders_per_day, status, is_active',
        )
        .eq('id', ppId)
        .maybeSingle();
    return row;
  }

  // Fallback: check owner_profile_id
  final row = await _client
      .from('pickup_points')
      .select(
        'id, name, owner_name, address_text, phone, email, city, area, '
        'image_url, opens_at, closes_at, opening_hours, preferred_payment_method, '
        'payment_handling_method, working_days, max_orders_per_day, status, is_active',
      )
      .eq('owner_profile_id', user.id)
      .maybeSingle();
  return row;
}

  Future<List<Map<String, dynamic>>> getPickupPointsForSearch() async {
    final rows = await _client
        .from('pickup_points')
        .select(
          'id, name, owner_name, address_text, city, area, phone, image_url, '
          'opening_hours, working_days, max_orders_per_day, '
          'preferred_payment_method, payment_handling_method, status',
        )
        .eq('is_active', true)
        .order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, int>> getPickupPointUsageCounts(List<String> pickupPointIds) async {
    if (pickupPointIds.isEmpty) return {};

    final rows = await _client
        .from('orders')
        .select('pickup_point_id')
        .inFilter('pickup_point_id', pickupPointIds);

    final counts = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final pickupPointId = row['pickup_point_id']?.toString();
      if (pickupPointId == null || pickupPointId.isEmpty) continue;
      counts[pickupPointId] = (counts[pickupPointId] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<Map<String, dynamic>>> getPickupPointParcels({
    required String pickupPointId,
  }) async {
    final orderRows = await _client
        .from('orders')
        .select(
          'id, status, created_at, updated_at, customer_profile_id, pickup_point_id, '
          'customer_name, customer_phone, merchant_id',
        )
        .eq('pickup_point_id', pickupPointId)
        .order('created_at', ascending: false);

    final orders = List<Map<String, dynamic>>.from(orderRows);
    if (orders.isEmpty) return [];

    final customerIds = orders
        .map((order) => order['customer_profile_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final customers = customerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('profiles')
                .select('id, full_name, phone')
                .inFilter('id', customerIds),
          );

    final customerById = {
      for (final customer in customers)
        if (customer['id'] != null) customer['id'].toString(): customer,
    };

    return orders.map((order) {
      final customer =
          customerById[order['customer_profile_id']?.toString()] ?? {};

      return {
        'order_id': order['id']?.toString(),
        'status': order['status']?.toString(),
        'customer_name':
            customer['full_name']?.toString() ??
            order['customer_name']?.toString() ??
            'Customer',
        'customer_phone':
            customer['phone']?.toString() ??
            order['customer_phone']?.toString() ??
            '-',
      };
    }).toList();
  }

  Future<void> updateParcelStatus({
    required String orderId,
    required String newStatus,
  }) async {
    await _client.from('orders').update({
      'status': newStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  Future<String?> uploadIssuePhoto({
    required String orderId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path =
        'issues/$orderId-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _client.storage.from('pickup-point-storage').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('pickup-point-storage').getPublicUrl(path);
  }

  Future<void> reportParcelIssue({
    required String orderId,
    required String pickupPointId,
    required String issueType,
    required String description,
    String? photoUrl,
  }) async {
    await _client.from('order_events').insert({
      'order_id': orderId,
      'event_type': 'pickup_point_issue',
      'note': description.isEmpty ? issueType : '$issueType: $description',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    if (photoUrl != null && photoUrl.isNotEmpty) {
      await _client.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'pickup_point_issue_photo',
        'note': photoUrl,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Stream<List<Map<String, dynamic>>> watchPickupPointOrders(String pickupPointId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('pickup_point_id', pickupPointId)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }
}
