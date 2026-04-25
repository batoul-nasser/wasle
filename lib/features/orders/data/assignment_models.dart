enum DropoffType { home, pickupPoint }

enum RouteStopType { pickup, dropoff }

class AssignmentLocation {
  final String name;
  final String? address;
  final double? lat;
  final double? lng;

  const AssignmentLocation({
    required this.name,
    this.address,
    this.lat,
    this.lng,
  });

  bool get hasCoordinates => lat != null && lng != null;

  String get cacheIdentity {
    if (hasCoordinates) {
      return '${lat!.toStringAsFixed(4)},${lng!.toStringAsFixed(4)}';
    }
    final raw = [name, address].whereType<String>().join('|').trim();
    return raw.isEmpty ? 'unknown-location' : raw.toLowerCase();
  }

  static AssignmentLocation unknown(String label) {
    return AssignmentLocation(name: label);
  }
}

class OrderDemand {
  final double weightKg;
  final double volumeCm3;
  final int itemCount;

  const OrderDemand({
    required this.weightKg,
    required this.volumeCm3,
    required this.itemCount,
  });

  static const zero = OrderDemand(weightKg: 0, volumeCm3: 0, itemCount: 0);

  OrderDemand operator +(OrderDemand other) {
    return OrderDemand(
      weightKg: weightKg + other.weightKg,
      volumeCm3: volumeCm3 + other.volumeCm3,
      itemCount: itemCount + other.itemCount,
    );
  }

  OrderDemand operator -() {
    return OrderDemand(
      weightKg: -weightKg,
      volumeCm3: -volumeCm3,
      itemCount: -itemCount,
    );
  }

  bool fitsWithin(OrderDemand capacity) {
    return weightKg <= capacity.weightKg &&
        volumeCm3 <= capacity.volumeCm3 &&
        itemCount <= capacity.itemCount;
  }

  bool get isNonNegative {
    return weightKg >= 0 && volumeCm3 >= 0 && itemCount >= 0;
  }
}

class AssignmentOrder {
  final String id;
  final String companyId;
  final String merchantId;
  final AssignmentLocation pickupLocation;
  final AssignmentLocation dropoffLocation;
  final DropoffType dropoffType;
  final OrderDemand demand;
  final DateTime createdAt;
  final DateTime? timeWindowStart;
  final DateTime? timeWindowEnd;
  final int prioritySeconds;

  const AssignmentOrder({
    required this.id,
    required this.companyId,
    required this.merchantId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.dropoffType,
    required this.demand,
    required this.createdAt,
    required this.timeWindowStart,
    required this.timeWindowEnd,
    required this.prioritySeconds,
  });

  RouteStop pickupStop() {
    return RouteStop(
      orderId: id,
      type: RouteStopType.pickup,
      location: pickupLocation,
      demand: demand,
      serviceSeconds: 5 * 60,
      earliestArrivalAt: timeWindowStart,
      latestArrivalAt: null,
    );
  }

  RouteStop dropoffStop() {
    return RouteStop(
      orderId: id,
      type: RouteStopType.dropoff,
      location: dropoffLocation,
      demand: demand,
      serviceSeconds: dropoffType == DropoffType.home ? 10 * 60 : 4 * 60,
      earliestArrivalAt: null,
      latestArrivalAt: timeWindowEnd,
    );
  }
}

class CandidateDriver {
  final String id;
  final String? profileId;
  final String companyId;
  final String vehicleType;
  final OrderDemand capacity;
  final AssignmentLocation currentLocation;
  final DateTime? shiftStartAt;
  final DateTime? shiftEndAt;

  const CandidateDriver({
    required this.id,
    required this.profileId,
    required this.companyId,
    required this.vehicleType,
    required this.capacity,
    required this.currentLocation,
    required this.shiftStartAt,
    required this.shiftEndAt,
  });
}

class RouteStop {
  final String orderId;
  final RouteStopType type;
  final AssignmentLocation location;
  final OrderDemand demand;
  final int serviceSeconds;
  final DateTime? earliestArrivalAt;
  final DateTime? latestArrivalAt;

  const RouteStop({
    required this.orderId,
    required this.type,
    required this.location,
    required this.demand,
    required this.serviceSeconds,
    required this.earliestArrivalAt,
    required this.latestArrivalAt,
  });

  OrderDemand get loadDelta {
    return type == RouteStopType.pickup ? demand : -demand;
  }

  String get dbType {
    return type == RouteStopType.pickup ? 'pickup' : 'dropoff';
  }
}

class DriverRoute {
  final String driverId;
  final String companyId;
  final AssignmentLocation currentLocation;
  final OrderDemand vehicleCapacity;
  final OrderDemand initialLoad;
  final List<RouteStop> stops;

  const DriverRoute({
    required this.driverId,
    required this.companyId,
    required this.currentLocation,
    required this.vehicleCapacity,
    required this.initialLoad,
    required this.stops,
  });

  DriverRoute copyWith({
    AssignmentLocation? currentLocation,
    OrderDemand? initialLoad,
    List<RouteStop>? stops,
  }) {
    return DriverRoute(
      driverId: driverId,
      companyId: companyId,
      currentLocation: currentLocation ?? this.currentLocation,
      vehicleCapacity: vehicleCapacity,
      initialLoad: initialLoad ?? this.initialLoad,
      stops: stops ?? this.stops,
    );
  }
}

class RouteMetrics {
  final int travelSeconds;
  final int serviceSeconds;
  final int latenessSeconds;
  final DateTime completionAt;

  const RouteMetrics({
    required this.travelSeconds,
    required this.serviceSeconds,
    required this.latenessSeconds,
    required this.completionAt,
  });
}

class RouteInsertion {
  final CandidateDriver driver;
  final DriverRoute originalRoute;
  final DriverRoute plannedRoute;
  final int pickupIndex;
  final int dropoffIndex;
  final int feasibleInsertionCount;
  final double costSeconds;
  final RouteMetrics metrics;
  final int incrementalTravelSeconds;
  final int incrementalServiceSeconds;
  final int incrementalLatenessPenaltySeconds;

  const RouteInsertion({
    required this.driver,
    required this.originalRoute,
    required this.plannedRoute,
    required this.pickupIndex,
    required this.dropoffIndex,
    required this.feasibleInsertionCount,
    required this.costSeconds,
    required this.metrics,
    required this.incrementalTravelSeconds,
    required this.incrementalServiceSeconds,
    required this.incrementalLatenessPenaltySeconds,
  });
}

class AssignmentResult {
  final String orderId;
  final bool assigned;
  final String? driverId;
  final String reason;
  final double? costSeconds;
  final int testedDrivers;
  final int feasibleInsertions;

  const AssignmentResult({
    required this.orderId,
    required this.assigned,
    required this.driverId,
    required this.reason,
    required this.costSeconds,
    required this.testedDrivers,
    required this.feasibleInsertions,
  });

  factory AssignmentResult.assigned({
    required String orderId,
    required String driverId,
    required double costSeconds,
    required int testedDrivers,
    required int feasibleInsertions,
  }) {
    return AssignmentResult(
      orderId: orderId,
      assigned: true,
      driverId: driverId,
      reason: 'Assigned automatically',
      costSeconds: costSeconds,
      testedDrivers: testedDrivers,
      feasibleInsertions: feasibleInsertions,
    );
  }

  factory AssignmentResult.unassigned({
    required String orderId,
    required String reason,
    required int testedDrivers,
    required int feasibleInsertions,
  }) {
    return AssignmentResult(
      orderId: orderId,
      assigned: false,
      driverId: null,
      reason: reason,
      costSeconds: null,
      testedDrivers: testedDrivers,
      feasibleInsertions: feasibleInsertions,
    );
  }
}
