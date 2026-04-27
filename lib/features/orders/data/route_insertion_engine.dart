import 'dart:math' as math;

import 'assignment_models.dart';
import 'routing_service.dart';

class RouteCostPolicy {
  final int latenessPenaltyMultiplier;
  final int workloadBalancePenaltyPerStopSeconds;

  const RouteCostPolicy({
    this.latenessPenaltyMultiplier = 3,
    this.workloadBalancePenaltyPerStopSeconds = 45,
  });
}

class RouteInsertionEngine {
  final RoutingService routingService;
  final RouteCostPolicy costPolicy;

  const RouteInsertionEngine({
    required this.routingService,
    this.costPolicy = const RouteCostPolicy(),
  });

  Future<RouteInsertion?> findBestInsertion({
    required CandidateDriver driver,
    required DriverRoute route,
    required AssignmentOrder order,
    DateTime? now,
  }) async {
    if (!order.demand.fitsWithin(driver.capacity)) return null;
    final projectedCurrentLoad = route.initialLoad + order.demand;
    if (!route.initialLoad.isNonNegative ||
        !route.initialLoad.fitsWithin(route.vehicleCapacity) ||
        !projectedCurrentLoad.isNonNegative ||
        !projectedCurrentLoad.fitsWithin(route.vehicleCapacity)) {
      return null;
    }

    final startAt = _routeStart(driver, now ?? DateTime.now().toUtc());
    if (driver.shiftEndAt != null && startAt.isAfter(driver.shiftEndAt!)) {
      return null;
    }

    final baseMetrics = await _metricsForStops(
      driver: driver,
      route: route,
      stops: route.stops,
      startAt: startAt,
    );
    if (baseMetrics == null) return null;

    RouteInsertion? best;
    var feasibleCount = 0;
    final existingStopCount = route.stops.length;

    for (var pickupIndex = 0; pickupIndex <= existingStopCount; pickupIndex++) {
      for (
        var dropoffIndex = pickupIndex + 1;
        dropoffIndex <= existingStopCount + 1;
        dropoffIndex++
      ) {
        final candidateStops = List<RouteStop>.from(route.stops)
          ..insert(pickupIndex, order.pickupStop())
          ..insert(dropoffIndex, order.dropoffStop());

        final candidateMetrics = await _metricsForStops(
          driver: driver,
          route: route,
          stops: candidateStops,
          startAt: startAt,
        );
        if (candidateMetrics == null) continue;
        if (!_fitsShift(driver, candidateMetrics)) continue;

        feasibleCount++;
        final incrementalTravel = math.max(
          0,
          candidateMetrics.travelSeconds - baseMetrics.travelSeconds,
        );
        final incrementalService = math.max(
          0,
          candidateMetrics.serviceSeconds - baseMetrics.serviceSeconds,
        );
        final incrementalLateness = math.max(
          0,
          candidateMetrics.latenessSeconds - baseMetrics.latenessSeconds,
        );
        final latenessPenalty =
            incrementalLateness * costPolicy.latenessPenaltyMultiplier;
        final workloadBalancePenalty =
            route.stops.length *
            costPolicy.workloadBalancePenaltyPerStopSeconds;
        final cost =
            incrementalTravel +
            incrementalService +
            latenessPenalty +
            workloadBalancePenalty -
            order.prioritySeconds;

        final insertion = RouteInsertion(
          driver: driver,
          originalRoute: route,
          plannedRoute: route.copyWith(stops: candidateStops),
          pickupIndex: pickupIndex,
          dropoffIndex: dropoffIndex,
          feasibleInsertionCount: feasibleCount,
          costSeconds: cost.toDouble(),
          metrics: candidateMetrics,
          incrementalTravelSeconds: incrementalTravel,
          incrementalServiceSeconds: incrementalService,
          incrementalLatenessPenaltySeconds: latenessPenalty,
        );

        if (best == null || insertion.costSeconds < best.costSeconds) {
          best = insertion;
        }
      }
    }

    if (best == null) return null;
    return RouteInsertion(
      driver: best.driver,
      originalRoute: best.originalRoute,
      plannedRoute: best.plannedRoute,
      pickupIndex: best.pickupIndex,
      dropoffIndex: best.dropoffIndex,
      feasibleInsertionCount: feasibleCount,
      costSeconds: best.costSeconds,
      metrics: best.metrics,
      incrementalTravelSeconds: best.incrementalTravelSeconds,
      incrementalServiceSeconds: best.incrementalServiceSeconds,
      incrementalLatenessPenaltySeconds: best.incrementalLatenessPenaltySeconds,
    );
  }

  DateTime _routeStart(CandidateDriver driver, DateTime now) {
    final shiftStart = driver.shiftStartAt;
    if (shiftStart != null && now.isBefore(shiftStart)) return shiftStart;
    return now;
  }

  bool _fitsShift(CandidateDriver driver, RouteMetrics metrics) {
    final shiftEnd = driver.shiftEndAt;
    return shiftEnd == null || !metrics.completionAt.isAfter(shiftEnd);
  }

  Future<RouteMetrics?> _metricsForStops({
    required CandidateDriver driver,
    required DriverRoute route,
    required List<RouteStop> stops,
    required DateTime startAt,
  }) async {
    var load = route.initialLoad;
    if (!load.isNonNegative || !load.fitsWithin(route.vehicleCapacity)) {
      return null;
    }

    var clock = startAt;
    var previousLocation = route.currentLocation;
    var travelSeconds = 0;
    var serviceSeconds = 0;
    var latenessSeconds = 0;

    for (final stop in stops) {
      load = load + stop.loadDelta;
      if (!load.isNonNegative || !load.fitsWithin(route.vehicleCapacity)) {
        return null;
      }

      final travel = await routingService.getTravelEstimate(
        origin: previousLocation,
        destination: stop.location,
        departureTime: clock,
        vehicleType: driver.vehicleType,
      );
      travelSeconds += travel.durationSeconds;
      clock = clock.add(Duration(seconds: travel.durationSeconds));

      final earliest = stop.earliestArrivalAt;
      if (earliest != null && clock.isBefore(earliest)) {
        clock = earliest;
      }

      final latest = stop.latestArrivalAt;
      if (latest != null && clock.isAfter(latest)) {
        latenessSeconds += clock.difference(latest).inSeconds;
      }

      serviceSeconds += stop.serviceSeconds;
      clock = clock.add(Duration(seconds: stop.serviceSeconds));
      previousLocation = stop.location;
    }

    return RouteMetrics(
      travelSeconds: travelSeconds,
      serviceSeconds: serviceSeconds,
      latenessSeconds: latenessSeconds,
      completionAt: clock,
    );
  }
}
