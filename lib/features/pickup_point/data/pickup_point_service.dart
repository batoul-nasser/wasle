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
          .select(
            'pickup_point_id, pickup_points('
            'id, name, address_text, preferred_payment_method, payment_handling_method'
            ')',
          )
          .eq('profile_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return row['pickup_points'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[PickupPointService] getMyPickupPoint: $e');
      return null;
    }
  }

  bool usesWhishRemittance(Map<String, dynamic>? pickupPoint) {
    final preferred = pickupPoint?['preferred_payment_method']
        ?.toString()
        .trim()
        .toLowerCase();
    final handling = pickupPoint?['payment_handling_method']
        ?.toString()
        .trim()
        .toLowerCase();

    return preferred == 'wish_money' ||
        preferred == 'customer_pays_online' ||
        handling == 'customer_pays_online';
  }

  bool usesAgentCollection(Map<String, dynamic>? pickupPoint) {
    if (usesWhishRemittance(pickupPoint)) return false;

    final preferred = pickupPoint?['preferred_payment_method']
        ?.toString()
        .trim()
        .toLowerCase();
    final handling = pickupPoint?['payment_handling_method']
        ?.toString()
        .trim()
        .toLowerCase();

    return preferred == 'customer_pays_at_pickup' ||
        handling == 'customer_pays_at_pickup';
  }

  Future<List<String>> _ordersOwnedByDestinationPickup(String ppId) async {
    final rows = await _db
        .from('orders')
        .select('id')
        .eq('destination_pickup_point_id', ppId);
    return List<Map<String, dynamic>>.from(rows)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<void> _ensureDestinationOwnedOrder({
    required String orderId,
    required String pickupPointId,
  }) async {
    final row = await _db
        .from('orders')
        .select('id')
        .eq('id', orderId)
        .eq('destination_pickup_point_id', pickupPointId)
        .maybeSingle();
    if (row == null) {
      throw Exception(
        'This order is not assigned to your pickup point as destination.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getPendingCashOrders() async {
    try {
      final pp = await getMyPickupPoint();
      if (pp == null) return [];
      final ppId = pp['id'].toString();

      final ownedOrderIds = await _ordersOwnedByDestinationPickup(ppId);
      if (ownedOrderIds.isEmpty) return [];
      const paymentEligibleStatuses = [
        'failed',
        'customer_not_available',
        'pending_pickup_point_delivery',
        'dropped_at_pickup_point',
      ];
      final orders = await _db
          .from('orders')
          .select(
            'id, tracking_code, status, created_at, destination_pickup_point_id, dropoff_type',
          )
          .inFilter('id', ownedOrderIds)
          .inFilter('status', paymentEligibleStatuses);

      if ((orders as List).isEmpty) return [];
      final orderIds = orders.map((o) => o['id'].toString()).toList();

      final payments = await _db
          .from('payments')
          .select('id, order_id, amount, status, method')
          .inFilter('order_id', orderIds)
          .eq('method', 'cash_at_pickup')
          .eq('status', 'pending');

      final paymentMap = {
        for (final p in (payments as List)) p['order_id'].toString(): p,
      };

      return orders
          .where((o) => paymentMap.containsKey(o['id'].toString()))
          .map(
            (o) => {
              ...Map<String, dynamic>.from(o),
              'pickup_role': (o['dropoff_type']?.toString().toLowerCase() == 'home')
                  ? 'backup_option_2'
                  : 'destination_pickup',
              'payment_can_collect_here': true,
              'payment': paymentMap[o['id'].toString()],
            },
          )
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

  Future<List<Map<String, dynamic>>> getRecentRemittedOrders({
    DateTime? since,
    int limit = 20,
  }) async {
    try {
      final pp = await getMyPickupPoint();
      if (pp == null) return [];
      final ppId = pp['id'].toString();
      final effectiveSince =
          since ?? DateTime.now().toUtc().subtract(const Duration(days: 1));

      final ownedOrderIds = await _ordersOwnedByDestinationPickup(ppId);
      if (ownedOrderIds.isEmpty) return [];

      final remittances = await _db
          .from('pickup_point_remittances')
          .select('order_id, payment_id, amount, whish_ref, status, sent_at')
          .eq('pickup_point_id', ppId)
          .inFilter('order_id', ownedOrderIds)
          .gte('sent_at', effectiveSince.toIso8601String())
          .order('sent_at', ascending: false)
          .limit(limit);

      final rows = List<Map<String, dynamic>>.from(remittances);
      if (rows.isEmpty) return [];

      final orderIds = rows
          .map((row) => row['order_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final orders = await _db
          .from('orders')
          .select('id, tracking_code, customer_name, customer_phone, status')
          .inFilter('id', orderIds);

      final orderMap = {
        for (final order in List<Map<String, dynamic>>.from(orders))
          order['id'].toString(): order,
      };

      return rows.map((row) {
        final order =
            orderMap[row['order_id']?.toString()] ?? <String, dynamic>{};
        return {
          ...row,
          'tracking_code':
              order['tracking_code']?.toString() ??
              row['order_id']?.toString() ??
              '-',
          'customer_name': order['customer_name']?.toString() ?? 'Customer',
          'customer_phone': order['customer_phone']?.toString() ?? '-',
          'order_status': order['status']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('[PickupPointService] getRecentRemittedOrders: $e');
      return [];
    }
  }

  Future<double> getTotalRemittedAmountToday() async {
    final startOfDay = DateTime.now().toUtc();
    final since = DateTime.utc(
      startOfDay.year,
      startOfDay.month,
      startOfDay.day,
    );
    final rows = await getRecentRemittedOrders(since: since, limit: 100);

    return rows.fold<double>(0.0, (sum, row) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });
  }

  Future<List<Map<String, dynamic>>> getRecentAgentCollections({
    DateTime? since,
    int limit = 20,
  }) async {
    try {
      final pp = await getMyPickupPoint();
      if (pp == null) return [];
      final ppId = pp['id'].toString();
      final effectiveSince =
          since ?? DateTime.now().toUtc().subtract(const Duration(days: 1));

      final ordersAtPickupPoint = await _db
          .from('orders')
          .select('id')
          .eq('destination_pickup_point_id', ppId);

      final orderIds = List<Map<String, dynamic>>.from(ordersAtPickupPoint)
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      if (orderIds.isEmpty) return [];

      final eventRows = await _db
          .from('order_events')
          .select('order_id, event_type, note, created_at, created_by')
          .inFilter('order_id', orderIds)
          .inFilter('event_type', [
            'agent_cash_collected',
            'agent_cash_collected_pickup_point_confirmed',
          ])
          .gte('created_at', effectiveSince.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      final events = List<Map<String, dynamic>>.from(eventRows);
      if (events.isEmpty) return [];

      final collectedOrderIds = events
          .map((row) => row['order_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final actorIds = events
          .map((row) => row['created_by']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final orderRows = await _db
          .from('orders')
          .select('id, tracking_code, customer_name, customer_phone, status')
          .inFilter('id', collectedOrderIds);
      final paymentRows = await _db
          .from('payments')
          .select('order_id, amount, status')
          .inFilter('order_id', collectedOrderIds);
      final profileRows = actorIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await _db
                  .from('profiles')
                  .select('id, full_name, phone')
                  .inFilter('id', actorIds),
            );

      final orderMap = {
        for (final order in List<Map<String, dynamic>>.from(orderRows))
          order['id'].toString(): order,
      };
      final paymentMap = {
        for (final payment in List<Map<String, dynamic>>.from(paymentRows))
          payment['order_id'].toString(): payment,
      };
      final profileMap = {
        for (final profile in profileRows) profile['id'].toString(): profile,
      };

      return events.map((event) {
        final orderId = event['order_id']?.toString() ?? '';
        final order = orderMap[orderId] ?? <String, dynamic>{};
        final payment = paymentMap[orderId] ?? <String, dynamic>{};
        final actor =
            profileMap[event['created_by']?.toString()] ?? <String, dynamic>{};

        return {
          ...event,
          'tracking_code':
              order['tracking_code']?.toString() ?? orderId.ifEmpty('-'),
          'customer_name': order['customer_name']?.toString() ?? 'Customer',
          'customer_phone': order['customer_phone']?.toString() ?? '-',
          'order_status': order['status']?.toString() ?? '',
          'amount': (payment['amount'] as num?)?.toDouble() ?? 0.0,
          'payment_status': payment['status']?.toString() ?? '',
          'collector_name': actor['full_name']?.toString() ?? '',
          'collector_phone': actor['phone']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('[PickupPointService] getRecentAgentCollections: $e');
      return [];
    }
  }

  Future<void> confirmCollectedByAgent({
    required String orderId,
    required String paymentId,
    required double amount,
    String? note,
  }) async {
    try {
      final pp = await getMyPickupPoint();
      if (pp == null) throw Exception('Pickup point not found');
      await _ensureDestinationOwnedOrder(
        orderId: orderId,
        pickupPointId: pp['id'].toString(),
      );

      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final response = await Supabase.instance.client.functions.invoke(
        'mark_cash_paid',
        headers: {'Authorization': 'Bearer $token'},
        body: {'order_id': orderId},
      );

      if (response.status != 200) {
        throw Exception(
          response.data['error'] ?? 'Failed to mark payment as paid',
        );
      }

      await _db.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'agent_cash_collected_pickup_point_confirmed',
        'created_by': _uid,
        'note':
            'Pickup point confirmed the agent collected cash.'
            ' Amount: \$${amount.toStringAsFixed(2)}'
            '${note != null && note.trim().isNotEmpty ? '. Note: ${note.trim()}' : ''}',
      });
    } catch (e) {
      debugPrint('[PickupPointService] confirmCollectedByAgent: $e');
      rethrow;
    }
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
      await _ensureDestinationOwnedOrder(
        orderId: orderId,
        pickupPointId: pp['id'].toString(),
      );

      // Call Edge Function instead of writing directly to payments
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final response = await Supabase.instance.client.functions.invoke(
        'mark_cash_paid',
        headers: {'Authorization': 'Bearer $token'},
        body: {'order_id': orderId},
      );

      if (response.status != 200) {
        throw Exception(
          response.data['error'] ?? 'Failed to mark payment as paid',
        );
      }

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

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}