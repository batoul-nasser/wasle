// lib/core/services/payment_service.dart
//
// RULE: Flutter NEVER writes payment status directly.
//       All state changes go through Edge Functions.
 
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/services/supabase_service.dart';
import 'package:wasle/features/payment/data/payment_model.dart';
 
class PaymentService {
  SupabaseClient get _db => SupabaseService.client;
 
  // ─── READ ────────────────────────────────────────────────────────────────
 
  /// Fetch the payment record for a given order.
  /// Returns null if none exists yet.
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
 
  /// Real-time stream: emits the payment row every time it changes.
  /// Use in customer dashboard to watch for Whish webhook confirmation.
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
 
  // ─── EDGE FUNCTION CALLS ─────────────────────────────────────────────────
  // All payment state mutations go through Edge Functions, never direct DB writes.
 
  /// Called when a merchant creates an order with a payment method chosen.
  /// Edge Function creates the order row AND the payment row atomically.
  /// Returns: { order_id, payment_id, tracking_code }
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
  }) async {
    try {
      final response = await _db.functions.invoke(
        'create_order',
        body: {
          'merchant_id': merchantId,
          if (branchId != null) 'branch_id': branchId,
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
        },
      );
 
      if (response.status != 200) {
        throw Exception('create_order failed: ${response.data}');
      }
 
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      throw Exception('Order creation failed: ${e.reasonPhrase}');
    }
  }
 
  /// Mark a cash order as paid at pickup point.
  /// Called by a field agent or pickup-point operator, NOT the customer.
  /// Returns: { success: true }
  Future<void> markCashPaid({
    required String orderId,
    required String collectedBy, // agent profile_id
  }) async {
    try {
      final response = await _db.functions.invoke(
        'mark_cash_paid',
        body: {
          'order_id': orderId,
          'collected_by': collectedBy,
        },
      );
 
      if (response.status != 200) {
        throw Exception('mark_cash_paid failed: ${response.data}');
      }
    } on FunctionException catch (e) {
      throw Exception('Cash payment confirmation failed: ${e.reasonPhrase}');
    }
  }
 
  /// Initiate a Whish online payment.
  /// Edge Function calls Whish API and returns a redirect URL.
  /// Flutter opens this URL in a WebView or browser.
  /// Returns: { payment_url, payment_ref }
  Future<Map<String, dynamic>> initWhishPayment({
    required String orderId,
    required double amount,
    required String customerPhone,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'init_whish_payment',
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
    } on FunctionException catch (e) {
      throw Exception('Whish payment init failed: ${e.reasonPhrase}');
    }
  }
 
  /// Request a refund for an order.
  /// Only callable with appropriate role (company_admin or platform_admin).
  /// Returns: { success: true, refund_id }
  Future<Map<String, dynamic>> requestRefund({
    required String orderId,
    required String reason,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'process_refund',
        body: {
          'order_id': orderId,
          'reason': reason,
        },
      );
 
      if (response.status != 200) {
        throw Exception('process_refund failed: ${response.data}');
      }
 
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      throw Exception('Refund request failed: ${e.reasonPhrase}');
    }
  }
 
  /// Confirm an agent collection (field agent collected cash from pickup point).
  Future<void> confirmAgentCollection({
    required String collectionId,
    required String agentId,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'confirm_agent_collection',
        body: {
          'collection_id': collectionId,
          'agent_id': agentId,
        },
      );
 
      if (response.status != 200) {
        throw Exception('confirm_agent_collection failed: ${response.data}');
      }
    } on FunctionException catch (e) {
      throw Exception('Agent collection confirmation failed: ${e.reasonPhrase}');
    }
  }
}