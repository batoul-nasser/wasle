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

    final planningNow = now ?? DateTime.now().toUtc();
    final shiftWindows = _resolveShiftWindows(driver, planningNow);
    if (shiftWindows.isEmpty) {
      return null;
    }

    RouteInsertion? best;
    var feasibleCount = 0;
    final existingStopCount = route.stops.length;
    for (final shiftWindow in shiftWindows) {
      final startAt = shiftWindow.startAt;
      final baseMetrics = await _metricsForStops(
        driver: driver,
        route: route,
        stops: route.stops,
        startAt: startAt,
      );
      if (baseMetrics == null) continue;

      for (
        var pickupIndex = 0;
        pickupIndex <= existingStopCount;
        pickupIndex++
      ) {
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
          if (!_fitsShift(candidateMetrics, shiftWindow)) continue;

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
          final deferPenaltySeconds = math.max(
            0,
            shiftWindow.startAt.difference(planningNow).inSeconds,
          );
          final cost =
              incrementalTravel +
              incrementalService +
              latenessPenalty +
              workloadBalancePenalty +
              deferPenaltySeconds -
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

  List<_ShiftWindow> _resolveShiftWindows(CandidateDriver driver, DateTime nowUtc) {
    final shiftStart = driver.shiftStartAt?.toUtc();
    final shiftEnd = driver.shiftEndAt?.toUtc();

    if (shiftStart == null && shiftEnd == null) {
      return [_ShiftWindow(startAt: nowUtc, endAt: null)];
    }

    // If only one side exists, keep backwards-compatible behavior.
    if (shiftStart == null) {
      if (nowUtc.isAfter(shiftEnd!)) return const [];
      return [_ShiftWindow(startAt: nowUtc, endAt: shiftEnd)];
    }
    if (shiftEnd == null) {
      final startAt = nowUtc.isBefore(shiftStart) ? shiftStart : nowUtc;
      return [_ShiftWindow(startAt: startAt, endAt: null)];
    }

    // Treat shift_start/end as daily recurring shift boundaries.
    final startMinutes = shiftStart.hour * 60 + shiftStart.minute;
    final endMinutes = shiftEnd.hour * 60 + shiftEnd.minute;
    final isOvernight = endMinutes <= startMinutes;
    final todayWindow = _dailyShiftWindowForDate(
      base: nowUtc,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      isOvernight: isOvernight,
    );
    final tomorrowWindow = _dailyShiftWindowForDate(
      base: nowUtc.add(const Duration(days: 1)),
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      isOvernight: isOvernight,
    );

    final windows = <_ShiftWindow>[];
    if (nowUtc.isBefore(todayWindow.startAt)) {
      windows.add(todayWindow);
    } else if (!nowUtc.isAfter(todayWindow.endAt!)) {
      windows.add(_ShiftWindow(startAt: nowUtc, endAt: todayWindow.endAt));
      windows.add(tomorrowWindow);
    } else {
      windows.add(tomorrowWindow);
    }
    return windows;
  }

  _ShiftWindow _dailyShiftWindowForDate({
    required DateTime base,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required bool isOvernight,
  }) {
    final startAt = DateTime.utc(
      base.year,
      base.month,
      base.day,
      shiftStart.hour,
      shiftStart.minute,
      shiftStart.second,
    );
    var endAt = DateTime.utc(
      base.year,
      base.month,
      base.day,
      shiftEnd.hour,
      shiftEnd.minute,
      shiftEnd.second,
    );
    if (isOvernight) {
      endAt = endAt.add(const Duration(days: 1));
    }
    return _ShiftWindow(startAt: startAt, endAt: endAt);
  }

  bool _fitsShift(RouteMetrics metrics, _ShiftWindow shiftWindow) {
    final endAt = shiftWindow.endAt;
    return endAt == null || !metrics.completionAt.isAfter(endAt);
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

class _ShiftWindow {
  final DateTime startAt;
  final DateTime? endAt;

  const _ShiftWindow({required this.startAt, required this.endAt});
}
