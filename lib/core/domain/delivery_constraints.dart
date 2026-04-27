class VehicleCapacityProfile {
  final int itemCount;
  final double weightKg;
  final double volumeCm3;

  const VehicleCapacityProfile({
    required this.itemCount,
    required this.weightKg,
    required this.volumeCm3,
  });

  static const motorcycle = VehicleCapacityProfile(
    itemCount: 20,
    weightKg: 25,
    volumeCm3: 70000,
  );
  static const car = VehicleCapacityProfile(
    itemCount: 70,
    weightKg: 120,
    volumeCm3: 450000,
  );
  static const van = VehicleCapacityProfile(
    itemCount: 140,
    weightKg: 450,
    volumeCm3: 1800000,
  );
}

class NormalizedOrderDemand {
  final int itemCount;
  final double weightKg;
  final double volumeCm3;

  const NormalizedOrderDemand({
    required this.itemCount,
    required this.weightKg,
    required this.volumeCm3,
  });
}

class DeliveryConstraintDefaults {
  static VehicleCapacityProfile capacityForVehicleType(String? vehicleType) {
    switch (vehicleType?.trim().toLowerCase()) {
      case 'car':
        return VehicleCapacityProfile.car;
      case 'van':
        return VehicleCapacityProfile.van;
      case 'motorcycle':
      default:
        return VehicleCapacityProfile.motorcycle;
    }
  }

  static NormalizedOrderDemand normalizeOrderDemand({
    int? itemCount,
    double? weightKg,
    double? volumeCm3,
  }) {
    return NormalizedOrderDemand(
      itemCount: (itemCount ?? 1) <= 0 ? 1 : itemCount!,
      weightKg: (weightKg ?? 1).isFinite && (weightKg ?? 1) > 0 ? weightKg! : 1,
      volumeCm3:
          (volumeCm3 ?? 1000).isFinite && (volumeCm3 ?? 1000) > 0
              ? volumeCm3!
              : 1000,
    );
  }
}
