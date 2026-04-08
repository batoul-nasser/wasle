class MerchantNotificationModel {
  final String orderId;
  final String trackingCode;
  final String eventType;
  final String title;
  final String body;
  final String? createdAt;
  final String? status;

  const MerchantNotificationModel({
    required this.orderId,
    required this.trackingCode,
    required this.eventType,
    required this.title,
    required this.body,
    this.createdAt,
    this.status,
  });
}
