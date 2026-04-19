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
  final String? dropoffAddress;

  final String customerName;
  final String customerPhone;

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
    required this.dropoffAddress,
    required this.customerName,
    required this.customerPhone,
    required this.branchName,
    required this.branchAddress,
    required this.branchLat,
    required this.branchLng,
  });
}
