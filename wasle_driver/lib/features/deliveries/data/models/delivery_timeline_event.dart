class DeliveryTimelineEvent {
  final String id;
  final String orderId;
  final String eventType;
  final String? note;
  final DateTime createdAt;
  final String? createdById;
  final String? createdByName;

  const DeliveryTimelineEvent({
    required this.id,
    required this.orderId,
    required this.eventType,
    required this.note,
    required this.createdAt,
    required this.createdById,
    required this.createdByName,
  });
}
