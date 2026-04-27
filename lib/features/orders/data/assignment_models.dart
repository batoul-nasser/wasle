import 'package:wasle/core/domain/delivery_constraints.dart';

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

  String get cacheIdentity =>
      hasCoordinates ? '${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}' : '$name|${address ?? ''}';
}

class OrderDemand {
  final int itemCount;
  final double weightKg;
  final double volumeCm3;

  const OrderDemand({
    required this.itemCount,
    required this.weightKg,
    required this.volumeCm3,
  });

  static const zero = OrderDemand(itemCount: 0, weightKg: 0, volumeCm3: 0);

  bool get isNonNegative =>
      itemCount >= 0 && weightKg >= 0 && volumeCm3 >= 0;

  bool fitsWithin(Object capacity) {
    final dynamic c = capacity;
    return itemCount <= c.itemCount &&
        weightKg <= c.weightKg &&
        volumeCm3 <= c.volumeCm3;
  }

  OrderDemand operator +(OrderDemand other) {
    return OrderDemand(
      itemCount: itemCount + other.itemCount,
      weightKg: weightKg + other.weightKg,
      volumeCm3: volumeCm3 + other.volumeCm3,
    );
  }
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
    this.earliestArrivalAt,
    this.latestArrivalAt,
  });

  OrderDemand get loadDelta =>
      type == RouteStopType.pickup
          ? demand
          : OrderDemand(
              itemCount: -demand.itemCount,
              weightKg: -demand.weightKg,
              volumeCm3: -demand.volumeCm3,
            );

  String get dbType => type == RouteStopType.pickup ? 'pickup' : 'dropoff';
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
    this.timeWindowStart,
    this.timeWindowEnd,
    this.prioritySeconds = 0,
  });

  RouteStop pickupStop() => RouteStop(
    orderId: id,
    type: RouteStopType.pickup,
    location: pickupLocation,
    demand: demand,
    serviceSeconds: 5 * 60,
    earliestArrivalAt: timeWindowStart,
  );

  RouteStop dropoffStop() => RouteStop(
    orderId: id,
    type: RouteStopType.dropoff,
    location: dropoffLocation,
    demand: demand,
    serviceSeconds: 10 * 60,
    latestArrivalAt: timeWindowEnd,
  );
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
    this.shiftStartAt,
    this.shiftEndAt,
  });
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
  final bool assigned;
  final String orderId;
  final String? driverId;
  final String? reason;
  final double? costSeconds;
  final int testedDrivers;
  final int feasibleInsertions;

  const AssignmentResult._({
    required this.assigned,
    required this.orderId,
    this.driverId,
    this.reason,
    this.costSeconds,
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
    return AssignmentResult._(
      assigned: true,
      orderId: orderId,
      driverId: driverId,
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
    return AssignmentResult._(
      assigned: false,
      orderId: orderId,
      reason: reason,
      testedDrivers: testedDrivers,
      feasibleInsertions: feasibleInsertions,
    );
  }
}
