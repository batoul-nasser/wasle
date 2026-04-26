class DriverDelivery {
  final String assignmentId;
  final String orderId;
  final String? companyId;
  final String? driverId;
  final DateTime? assignedAt;
  final DateTime? completedAt;

  final String trackingCode;
  final String status;
  final String? notes;

  final String merchantName;

  final String pickupPointName;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupPointId;
  final String? dropoffType;
  final String? dropoffName;
  final String? dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;

  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final int? itemCount;
  final double? estimatedWeightKg;
  final double? estimatedVolumeCm3;

  final String? branchName;
  final String? branchAddress;
  final double? branchLat;
  final double? branchLng;

  const DriverDelivery({
    required this.assignmentId,
    required this.orderId,
    required this.companyId,
    required this.driverId,
    required this.assignedAt,
    required this.completedAt,
    required this.trackingCode,
    required this.status,
    required this.notes,
    required this.merchantName,
    required this.pickupPointName,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupPointId,
    required this.dropoffType,
    required this.dropoffName,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.itemCount,
    required this.estimatedWeightKg,
    required this.estimatedVolumeCm3,
    required this.branchName,
    required this.branchAddress,
    required this.branchLat,
    required this.branchLng,
  });
}
