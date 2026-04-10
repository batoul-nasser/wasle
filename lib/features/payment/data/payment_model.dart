// lib/features/payment/data/payment_model.dart
 
enum PaymentMethod { cashAtPickup, whishOnline }
 
enum PaymentStatus { pending, paid, failed, refunded }
 
extension PaymentMethodX on PaymentMethod {
  String get dbValue =>
      this == PaymentMethod.cashAtPickup ? 'cash_at_pickup' : 'whish_online';
 
  String get displayName =>
      this == PaymentMethod.cashAtPickup ? 'Cash at Pickup Point' : 'Whish Online';
 
  static PaymentMethod fromDb(String? value) {
    if (value == 'whish_online') return PaymentMethod.whishOnline;
    return PaymentMethod.cashAtPickup;
  }
}
 
extension PaymentStatusX on PaymentStatus {
  String get dbValue {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.refunded:
        return 'refunded';
    }
  }
 
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
 
  static PaymentStatus fromDb(String? value) {
    switch (value) {
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.pending;
    }
  }
}
 
class PaymentModel {
  final String id;
  final String orderId;
  final PaymentMethod method;
  final PaymentStatus status;
  final double amount;
  final String? transactionRef;
  final String createdAt;
  final String? updatedAt;
 
  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.method,
    required this.status,
    required this.amount,
    this.transactionRef,
    required this.createdAt,
    this.updatedAt,
  });
 
  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      method: PaymentMethodX.fromDb(map['method']?.toString()),
      status: PaymentStatusX.fromDb(map['status']?.toString()),
      amount: ((map['amount'] ?? 0) as num).toDouble(),
      transactionRef: map['transaction_ref']?.toString(),
      createdAt: map['created_at']?.toString() ?? '',
      updatedAt: map['updated_at']?.toString(),
    );
  }
 
  bool get isPaid => status == PaymentStatus.paid;
  bool get isPending => status == PaymentStatus.pending;
  bool get isCash => method == PaymentMethod.cashAtPickup;
  bool get isWhish => method == PaymentMethod.whishOnline;
}