import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/services/supabase_service.dart';

class PickupPointService {
  SupabaseClient get _db => SupabaseService.client;
  String? get _uid => _db.auth.currentUser?.id;

  Future<Map<String, dynamic>?> getMyPickupPoint() async {
    try {
      final uid = _uid;
      if (uid == null) return null;
      final row = await _db
          .from('pickup_point_operators')
          .select('pickup_point_id, pickup_points(id, name, address_text)')
          .eq('profile_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return row['pickup_points'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[PickupPointService] getMyPickupPoint: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingCashOrders() async {
    try {
      final pp = await getMyPickupPoint();
      if (pp == null) return [];
      final ppId = pp['id'].toString();

      final orders = await _db
          .from('orders')
          .select('id, tracking_code, status, created_at')
          .eq('pickup_point_id', ppId)
          .eq('status', 'dropped_at_pickup_point');

      if ((orders as List).isEmpty) return [];
      final orderIds = orders.map((o) => o['id'].toString()).toList();

      final payments = await _db
          .from('payments')
          .select('id, order_id, amount, status, method')
          .inFilter('order_id', orderIds)
          .eq('method', 'cash_at_pickup')
          .eq('status', 'pending');

      final paymentMap = {
        for (final p in (payments as List)) p['order_id'].toString(): p
      };

      return orders
          .where((o) => paymentMap.containsKey(o['id'].toString()))
          .map((o) => {
                ...Map<String, dynamic>.from(o),
                'payment': paymentMap[o['id'].toString()],
              })
          .toList();
    } catch (e) {
      debugPrint('[PickupPointService] getPendingCashOrders: $e');
      return [];
    }
  }

  Future<double> getTotalPendingAmount() async {
  final orders = await getPendingCashOrders();

  return orders.fold<double>(0.0, (sum, o) {
    final payment = o['payment'] as Map<String, dynamic>?;
    final amount = (payment?['amount'] as num?)?.toDouble() ?? 0.0;
    return sum + amount;
  });
}

  Future<void> confirmSentToWasle({
    required String orderId,
    required String paymentId,
    required double amount,
    required String whishRef,
  }) async {
    try {
      final pp = await getMyPickupPoint();
      if (pp == null) throw Exception('Pickup point not found');

      await _db.from('pickup_point_remittances').insert({
        'pickup_point_id': pp['id'].toString(),
        'order_id': orderId,
        'payment_id': paymentId,
        'amount': amount,
        'whish_ref': whishRef,
        'status': 'sent',
        'sent_at': DateTime.now().toUtc().toIso8601String(),
        'created_by': _uid,
      });

      await _db
          .from('payments')
          .update({'status': 'paid'})
          .eq('id', paymentId);

      await _db.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'remittance_sent',
        'created_by': _uid,
        'note': 'Cash sent to Wasle via Whish. Ref: $whishRef',
      });
    } catch (e) {
      debugPrint('[PickupPointService] confirmSentToWasle: $e');
      rethrow;
    }
  }
}