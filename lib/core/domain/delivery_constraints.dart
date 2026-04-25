class VehicleCapacityProfile {
  final double weightKg;
  final double volumeCm3;
  final int itemCount;

  const VehicleCapacityProfile({
    required this.weightKg,
    required this.volumeCm3,
    required this.itemCount,
  });
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
  static const double estimatedWeightKgPerItem = 1.5;
  static const double estimatedVolumeCm3PerItem = 5000;

  static const VehicleCapacityProfile motorcycle = VehicleCapacityProfile(
    weightKg: 15,
    volumeCm3: 40000,
    itemCount: 5,
  );

  static const VehicleCapacityProfile car = VehicleCapacityProfile(
    weightKg: 60,
    volumeCm3: 200000,
    itemCount: 20,
  );

  static const VehicleCapacityProfile van = VehicleCapacityProfile(
    weightKg: 300,
    volumeCm3: 1000000,
    itemCount: 80,
  );

  static VehicleCapacityProfile capacityForVehicleType(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'car':
        return car;
      case 'van':
        return van;
      default:
        return motorcycle;
    }
  }

  static NormalizedOrderDemand normalizeOrderDemand({
    required int? itemCount,
    required double? weightKg,
    required double? volumeCm3,
  }) {
    final normalizedItemCount = itemCount ?? 0;
    if (normalizedItemCount <= 0) {
      throw ArgumentError('item_count must be at least 1.');
    }

    if (weightKg != null && weightKg < 0) {
      throw ArgumentError('estimated_weight cannot be negative.');
    }
    if (volumeCm3 != null && volumeCm3 < 0) {
      throw ArgumentError('estimated_volume cannot be negative.');
    }

    final normalizedWeight =
        weightKg != null && weightKg > 0
            ? weightKg
            : normalizedItemCount * estimatedWeightKgPerItem;
    final normalizedVolume =
        volumeCm3 != null && volumeCm3 > 0
            ? volumeCm3
            : normalizedItemCount * estimatedVolumeCm3PerItem;

    if (normalizedWeight <= 0) {
      throw ArgumentError('estimated_weight must be greater than 0.');
    }
    if (normalizedVolume <= 0) {
      throw ArgumentError('estimated_volume must be greater than 0.');
    }

    return NormalizedOrderDemand(
      itemCount: normalizedItemCount,
      weightKg: normalizedWeight,
      volumeCm3: normalizedVolume,
    );
  }
}
