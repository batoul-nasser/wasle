// File: lib/core/services/payment_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/domain/delivery_constraints.dart';
import 'package:wasle/core/services/supabase_service.dart';
import 'package:wasle/features/payment/data/payment_model.dart';

class PaymentService {
  SupabaseClient get _db => SupabaseService.client;

  Map<String, String> get _authHeaders {
    final token = _db.auth.currentSession?.accessToken ?? '';
    return {'Authorization': 'Bearer $token'};
  }

  // ─── READ ─────────────────────────────────────────────────────────────────

  Future<PaymentModel?> getPaymentByOrderId(String orderId) async {
    try {
      final row = await _db
          .from('payments')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();
      if (row == null) return null;
      return PaymentModel.fromMap(row);
    } catch (e) {
      debugPrint('[PaymentService] getPaymentByOrderId error: $e');
      return null;
    }
  }

  Stream<PaymentModel?> watchPayment(String orderId) {
    return _db
        .from('payments')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return PaymentModel.fromMap(rows.first);
        });
  }

  // ─── CREATE ORDER + PAYMENT ───────────────────────────────────────────────

  /// Creates a new order via Edge Function.
  /// [itemCount], [estimatedWeightKg], [estimatedVolumeCm3] are required by
  /// the routing algorithm (PDF §4) for driver capacity matching.
  Future<Map<String, dynamic>> createOrderWithPayment({
    required String merchantId,
    required String? branchId,
    required String customerName,
    required String customerPhone,
    required String? customerEmail,
    required String address,
    required double amount,
    required PaymentMethod paymentMethod,
    String? pickupPointId,
    String? deliveryCompanyId,
    String? notes,
    int itemCount = 1,
    double estimatedWeightKg = 1.0,
    double estimatedVolumeCm3 = 500.0,
  }) async {
    try {
      final normalizedDemand = DeliveryConstraintDefaults.normalizeOrderDemand(
        itemCount: itemCount,
        weightKg: estimatedWeightKg,
        volumeCm3: estimatedVolumeCm3,
      );

      final response = await _db.functions.invoke(
        'create_order',
        headers: _authHeaders,
        body: {
          'merchant_id': merchantId,
          if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          if (customerEmail != null && customerEmail.isNotEmpty)
            'customer_email': customerEmail,
          'customer_address_text': address,
          'amount': amount,
          'payment_method': paymentMethod.dbValue,
          if (pickupPointId != null && pickupPointId.isNotEmpty)
            'pickup_point_id': pickupPointId,
          if (deliveryCompanyId != null && deliveryCompanyId.isNotEmpty)
            'delivery_company_id': deliveryCompanyId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'item_count': normalizedDemand.itemCount,
          'estimated_weight': normalizedDemand.weightKg,
          'estimated_volume': normalizedDemand.volumeCm3,
        },
      );

      debugPrint('[PaymentService] create_order status: ${response.status}');
      debugPrint('[PaymentService] create_order data: ${response.data}');

      if (response.status != 200) {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? response.data.toString())
            : response.data?.toString() ?? 'Unknown error';
        throw Exception('Order creation failed: $errorMsg');
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e, st) {
      debugPrint('[PaymentService] createOrderWithPayment error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─── CASH PAYMENT ──────────────────────────────────────────────────────────

  Future<void> markCashPaid({
    required String orderId,
    required String collectedBy,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'mark_cash_paid',
        headers: _authHeaders,
        body: {'order_id': orderId, 'collected_by': collectedBy},
      );
      if (response.status != 200) {
        throw Exception('mark_cash_paid failed: ${response.data}');
      }
    } catch (e) {
      throw Exception('Cash payment confirmation failed: $e');
    }
  }

  // ─── WHISH PAYMENT ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> initWhishPayment({
    required String orderId,
    required double amount,
    required String customerPhone,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'init_whish_payment',
        headers: _authHeaders,
        body: {
          'order_id': orderId,
          'amount': amount,
          'customer_phone': customerPhone,
        },
      );
      if (response.status != 200) {
        throw Exception('init_whish_payment failed: ${response.data}');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('Whish payment init failed: $e');
    }
  }

  // ─── REFUND ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestRefund({
    required String orderId,
    required String reason,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'process_refund',
        headers: _authHeaders,
        body: {'order_id': orderId, 'reason': reason},
      );
      if (response.status != 200) {
        throw Exception('process_refund failed: ${response.data}');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('Refund request failed: $e');
    }
  }

  // ─── AGENT COLLECTION ─────────────────────────────────────────────────────

  Future<void> confirmAgentCollection({
    required String collectionId,
    required String agentId,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'confirm_agent_collection',
        headers: _authHeaders,
        body: {'collection_id': collectionId, 'agent_id': agentId},
      );
      if (response.status != 200) {
        throw Exception('confirm_agent_collection failed: ${response.data}');
      }
    } catch (e) {
      throw Exception('Agent collection confirmation failed: $e');
    }
  }
}
