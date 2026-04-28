import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/services/supabase_service.dart';

class AgentService {
  SupabaseClient get _db => SupabaseService.client;
  String? get _uid => _db.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> getPickupPointsWithPendingCash() async {
    try {
      final pickupPoints = await _db
          .from('pickup_points')
          .select(
            'id, name, address_text, city, area, phone, email, owner_name, preferred_payment_method, status',
          )
          .or('preferred_payment_method.is.null,preferred_payment_method.neq.wish_money')
          .eq('is_active', true);

      final result = <Map<String, dynamic>>[];

      for (final pp in (pickupPoints as List)) {
        final ppId = pp['id'].toString();

        final orders = await _db
            .from('orders')
            .select(
              'id, tracking_code, status, created_at, dropoff_type, destination_pickup_point_id',
            )
            .eq('destination_pickup_point_id', ppId)
            .eq('dropoff_type', 'home')
            .inFilter('status', [
              'pending_pickup_point_delivery',
              'dropped_at_pickup_point',
              'ready_for_customer_pickup',
            ]);

        if ((orders as List).isEmpty) continue;

        final orderIds = orders.map((o) => o['id'].toString()).toList();

        final payments = await _db
            .from('payments')
            .select('id, order_id, amount, status, method')
            .inFilter('order_id', orderIds)
            .eq('method', 'cash_at_pickup')
            .eq('status', 'pending');

        if ((payments as List).isEmpty) continue;
        final agentCollections = List<Map<String, dynamic>>.from(
          await _db
              .from('agent_collections')
              .select('order_id, status')
              .inFilter('order_id', orderIds),
        );
        final collectionByOrderId = {
          for (final row in agentCollections)
            if (row['order_id'] != null) row['order_id'].toString(): row['status']?.toString(),
        };

        double totalPending = 0.0;
        final pendingOrders = <Map<String, dynamic>>[];

        for (final order in orders) {
          final payment = payments.firstWhere(
            (p) => p['order_id'].toString() == order['id'].toString(),
            orElse: () => <String, dynamic>{},
          );
          if (payment.isEmpty) continue;
          final collectionStatus =
              collectionByOrderId[order['id'].toString()]?.toLowerCase();
          if (collectionStatus != null &&
              collectionStatus.isNotEmpty &&
              collectionStatus != 'ready_for_agent') {
            continue;
          }
          final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
          totalPending += amount;
          pendingOrders.add({
            ...Map<String, dynamic>.from(order),
            'payment': Map<String, dynamic>.from(payment),
          });
        }

        if (pendingOrders.isEmpty) continue;

        result.add({
          ...Map<String, dynamic>.from(pp),
          'pending_orders': pendingOrders,
          'total_pending': totalPending,
          'order_count': pendingOrders.length,
        });
      }

      return result;
    } catch (e) {
      debugPrint('[AgentService] getPickupPointsWithPendingCash: $e');
      return [];
    }
  }

  Future<void> confirmCollection({
    required String orderId,
    required String paymentId,
    required double amount,
    required String pickupPointId,
    String? note,
  }) async {
    try {
      final agentId = _uid;
      if (agentId == null) throw Exception('Agent not logged in');

      final collectedAt = DateTime.now().toUtc().toIso8601String();
      final existing = await _db
          .from('agent_collections')
          .select('id, status')
          .eq('order_id', orderId)
          .eq('payment_id', paymentId)
          .eq('pickup_point_id', pickupPointId)
          .maybeSingle();
      if (existing == null) {
        await _db.from('agent_collections').insert({
          'agent_id': agentId,
          'order_id': orderId,
          'payment_id': paymentId,
          'pickup_point_id': pickupPointId,
          'amount': amount,
          'status': 'collected',
          'note': note ?? '',
          'collected_at': collectedAt,
        });
      } else {
        await _db
            .from('agent_collections')
            .update({
              'agent_id': agentId,
              'status': 'collected',
              'note': note ?? '',
              'collected_at': collectedAt,
            })
            .eq('id', existing['id']);
      }

      await _db
          .from('payments')
          .update({
            'collected_by': agentId,
            'collected_at': collectedAt,
            'status': 'paid',
            'updated_at': collectedAt,
          })
          .eq('id', paymentId);

      await _db.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'agent_cash_collected',
        'created_by': agentId,
        'note': 'Agent collected cash from pickup point. Amount: \$$amount'
            '${note != null && note.isNotEmpty ? '. Note: $note' : ''}',
        'metadata': {
          'collected_by_agent_id': agentId,
          'pickup_point_id': pickupPointId,
          'amount': amount,
          'collected_at': collectedAt,
        },
      });
      debugPrint(
        '[AGENT_COLLECTION] tracking=$orderId paymentId=$paymentId pickupPointId=$pickupPointId status=collected agentId=$agentId collectedAt=$collectedAt',
      );
    } catch (e) {
      debugPrint('[AgentService] confirmCollection: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllAgents() async {
    try {
      final agents = await _db
          .from('profiles')
          .select('id, full_name, phone, status, created_at')
          .eq('role', 'agent')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(agents);
    } catch (e) {
      debugPrint('[AgentService] getAllAgents: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCollectionHistory({
    String? agentId,
  }) async {
    try {
      var query = _db.from('agent_collections').select(
            'id, agent_id, order_id, amount, status, note, collected_at, '
            'profiles!agent_collections_agent_id_fkey(full_name, phone), '
            'pickup_points(name, address_text)',
          );

      if (agentId != null) {
        query = query.eq('agent_id', agentId);
      }

      final rows = await query.order('collected_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('[AgentService] getCollectionHistory: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyCollections() async {
    final uid = _uid;
    if (uid == null) return [];
    return getCollectionHistory(agentId: uid);
  }

  Future<double> getTotalPendingAgentCash() async {
    try {
      final pps = await getPickupPointsWithPendingCash();
      return pps.fold<double>(
        0.0,
        (sum, pp) => sum + ((pp['total_pending'] as num?)?.toDouble() ?? 0.0),
      );
    } catch (e) {
      return 0.0;
    }
  }
}
