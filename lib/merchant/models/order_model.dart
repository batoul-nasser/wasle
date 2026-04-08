class OrderModel {
  final String id;
  final String trackingCode;
  final String status;
  final double codAmount;
  final String createdAt;
  final String pickupMethod;

  final String customerName;
  final String customerPhone;
  final String? customerEmail;

  final String address;
  final String? notes;
  final String? preferredTimeWindow;

  final String? assignedCompany;
  final String? driverName;
  final String? driverPhone;
  final String? expectedPickupTime;

  final String? failedReason;
  final String? resolution;

  final List<String> timeline;

  const OrderModel({
    required this.id,
    required this.trackingCode,
    required this.status,
    required this.codAmount,
    required this.createdAt,
    required this.pickupMethod,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.address,
    this.notes,
    this.preferredTimeWindow,
    this.assignedCompany,
    this.driverName,
    this.driverPhone,
    this.expectedPickupTime,
    this.failedReason,
    this.resolution,
    this.timeline = const [],
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final pickupPointId = map['pickup_point_id']?.toString();

    return OrderModel(
      id: map['id']?.toString() ?? '',
      trackingCode: map['tracking_code']?.toString() ?? '',
      status: _normalizeStatus(map['status']?.toString()),

      codAmount:
          ((map['declared_value'] ?? map['cod_amount']) as num?)?.toDouble() ??
              0.0,
      createdAt: _formatDate(map['created_at']?.toString()),
      pickupMethod: (pickupPointId != null && pickupPointId.isNotEmpty)
          ? 'Pickup Point'
          : 'From Store',
      customerName: map['customer_name']?.toString() ?? '',
      customerPhone: map['customer_phone']?.toString() ?? '',
      customerEmail: map['customer_email']?.toString(),
      address: map['customer_address_text']?.toString() ??
          map['dropoff_address']?.toString() ??
          '',
      notes: map['notes']?.toString(),
      preferredTimeWindow: map['preferred_time_window']?.toString(),
      assignedCompany: map['assigned_company']?.toString(),
      driverName: map['driver_name']?.toString(),
      driverPhone: map['driver_phone']?.toString(),
      expectedPickupTime: map['expected_pickup_time']?.toString(),
      failedReason: map['failed_reason']?.toString(),
      resolution: map['resolution']?.toString(),
    );
  }

  Map<String, dynamic> toInsertMap({
    required String merchantId,
    required String? branchId,
    required String trackingCode,
    String? pickupPointId,
  }) {
    return {
      'merchant_id': merchantId,
      if (branchId != null) 'branch_id': branchId,
      'tracking_code': trackingCode,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address_text': address,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
      if (codAmount > 0) 'declared_value': codAmount,
      if (pickupPointId != null && pickupPointId.trim().isNotEmpty)
        'pickup_point_id': pickupPointId,
      'status': status,
    };
  }

  OrderModel withTimeline(List<String> events) {
    return OrderModel(
      id: id,
      trackingCode: trackingCode,
      status: status,
      codAmount: codAmount,
      createdAt: createdAt,
      pickupMethod: pickupMethod,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      address: address,
      notes: notes,
      preferredTimeWindow: preferredTimeWindow,
      assignedCompany: assignedCompany,
      driverName: driverName,
      driverPhone: driverPhone,
      expectedPickupTime: expectedPickupTime,
      failedReason: failedReason,
      resolution: resolution,
      timeline: events,
    );
  }


  OrderModel copyWith({
    String? id,
    String? trackingCode,
    String? status,
    double? codAmount,
    String? createdAt,
    String? pickupMethod,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? address,
    String? notes,
    String? preferredTimeWindow,
    String? assignedCompany,
    String? driverName,
    String? driverPhone,
    String? expectedPickupTime,
    String? failedReason,
    String? resolution,
    List<String>? timeline,
  }) {
    return OrderModel(
      id: id ?? this.id,
      trackingCode: trackingCode ?? this.trackingCode,
      status: status ?? this.status,
      codAmount: codAmount ?? this.codAmount,
      createdAt: createdAt ?? this.createdAt,
      pickupMethod: pickupMethod ?? this.pickupMethod,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      preferredTimeWindow: preferredTimeWindow ?? this.preferredTimeWindow,
      assignedCompany: assignedCompany ?? this.assignedCompany,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      expectedPickupTime: expectedPickupTime ?? this.expectedPickupTime,
      failedReason: failedReason ?? this.failedReason,
      resolution: resolution ?? this.resolution,
      timeline: timeline ?? this.timeline,
    );
  }

  static String _normalizeStatus(String? raw) {
    final value = (raw ?? 'created').trim().toLowerCase();
    switch (value) {
      case 'returning_to_store':
        return 'returning';
      case 'returned':
        return 'returned_to_store';
      default:
        return value.isEmpty ? 'created' : value;
    }
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return 'Today, ${_time(dt)}';
      if (diff.inDays == 1) return 'Yesterday, ${_time(dt)}';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  static String _time(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $ap';
  }
}