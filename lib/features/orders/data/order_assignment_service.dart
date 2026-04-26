import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/domain/delivery_constraints.dart';
import 'package:wasle/core/services/supabase_service.dart';

import 'assignment_models.dart';
import 'route_insertion_engine.dart';
import 'routing_service.dart';

class OrderAssignmentService {
  final SupabaseClient _db;
  final RoutingService _routingService;
  late final RouteInsertionEngine _insertionEngine;

  OrderAssignmentService({
    SupabaseClient? client,
    RoutingService? routingService,
  }) : _db = client ?? SupabaseService.client,
       _routingService = routingService ?? SupabaseEdgeRoutingService() {
    _insertionEngine = RouteInsertionEngine(routingService: _routingService);
  }

  Future<AssignmentResult> autoAssignOrderFromCreationResponse(
    Map<String, dynamic> response, {
    required String merchantId,
    String? companyIdHint,
  }) async {
    final orderId = _extractOrderId(response);
    if (orderId == null || orderId.isEmpty) {
      return AssignmentResult.unassigned(
        orderId: 'unknown',
        reason:
            'Order was created, but the create_order response did not include an order id.',
        testedDrivers: 0,
        feasibleInsertions: 0,
      );
    }
    return autoAssignOrder(
      orderId,
      merchantIdHint: merchantId,
      companyIdHint: companyIdHint,
    );
  }

  Future<AssignmentResult> autoAssignOrder(
    String orderId, {
    String? merchantIdHint,
    String? companyIdHint,
  }) async {
    var testedDrivers = 0;
    var feasibleInsertions = 0;

    try {
      final order = await _loadAssignmentOrder(
        orderId,
        merchantIdHint: merchantIdHint,
        companyIdHint: companyIdHint,
      );
      if (order == null) {
        return AssignmentResult.unassigned(
          orderId: orderId,
          reason:
              'Order not found or missing company, package, or routing data.',
          testedDrivers: 0,
          feasibleInsertions: 0,
        );
      }

      final drivers = await _loadCandidateDrivers(order.companyId);
      testedDrivers = drivers.length;
      if (drivers.isEmpty) {
        await _recordUnassignedEvent(
          order.id,
          'No approved available drivers for company.',
        );
        return AssignmentResult.unassigned(
          orderId: order.id,
          reason: 'No approved available drivers for company.',
          testedDrivers: testedDrivers,
          feasibleInsertions: 0,
        );
      }

      RouteInsertion? bestInsertion;
      for (final driver in drivers) {
        final route = await _loadDriverRoute(driver);
        if (!_canCarryOrderNow(route: route, orderDemand: order.demand)) {
          continue;
        }
        final insertion = await _insertionEngine.findBestInsertion(
          driver: driver,
          route: route,
          order: order,
        );
        if (insertion == null) continue;

        feasibleInsertions += insertion.feasibleInsertionCount;
        if (bestInsertion == null ||
            insertion.costSeconds < bestInsertion.costSeconds) {
          bestInsertion = insertion;
        }
      }

      if (bestInsertion == null) {
        const reason =
            'No feasible driver found after capacity, shift, and route checks.';
        await _recordUnassignedEvent(order.id, reason);
        return AssignmentResult.unassigned(
          orderId: order.id,
          reason: reason,
          testedDrivers: testedDrivers,
          feasibleInsertions: feasibleInsertions,
        );
      }

      await _commitAssignment(order, bestInsertion);
      return AssignmentResult.assigned(
        orderId: order.id,
        driverId: bestInsertion.driver.id,
        costSeconds: bestInsertion.costSeconds,
        testedDrivers: testedDrivers,
        feasibleInsertions: feasibleInsertions,
      );
    } on _AutoAssignmentFailure catch (error) {
      await _recordUnassignedEvent(orderId, error.message);
      return AssignmentResult.unassigned(
        orderId: orderId,
        reason: error.message,
        testedDrivers: testedDrivers,
        feasibleInsertions: feasibleInsertions,
      );
    } catch (error) {
      await _recordUnassignedEvent(
        orderId,
        'Automatic assignment failed: $error',
      );
      return AssignmentResult.unassigned(
        orderId: orderId,
        reason: 'Automatic assignment failed: $error',
        testedDrivers: testedDrivers,
        feasibleInsertions: feasibleInsertions,
      );
    }
  }

  Future<AssignmentOrder?> _loadAssignmentOrder(
    String orderId, {
    String? merchantIdHint,
    String? companyIdHint,
  }) async {
    final orderRows = await _db
        .from('orders')
        .select('*')
        .eq('id', orderId)
        .limit(1);
    final orders = List<Map<String, dynamic>>.from(orderRows);
    if (orders.isEmpty) return null;

    final order = orders.first;
    final merchantId = _firstNonEmpty([order['merchant_id'], merchantIdHint]);
    if (merchantId == null) return null;

    var companyId = _firstNonEmpty([
      order['delivery_company_id'],
      order['company_id'],
      companyIdHint,
    ]);
    companyId ??= await _resolveActiveCompanyIdForMerchant(merchantId);
    if (companyId == null || companyId.isEmpty) return null;
    await _ensureOrderCompany(orderId: orderId, companyId: companyId);

    final branch = await _loadById('merchant_branches', order['branch_id']);
    final pickupPoint = await _loadById(
      'pickup_points',
      order['pickup_point_id'],
    );
    final address = await _loadOrderAddress(orderId);
    final dropoffType = _parseDropoffType(order);
    final demand = _tryOrderDemand(order);
    if (demand == null) {
      throw const _AutoAssignmentFailure(
        'Auto assignment failed: missing package demand',
      );
    }

    final pickupLocation = _pickupLocation(order, branch, pickupPoint, address);
    final dropoffLocation = _dropoffLocation(
      order,
      address,
      pickupPoint,
      dropoffType,
    );
    if (!pickupLocation.hasCoordinates || !dropoffLocation.hasCoordinates) {
      throw const _AutoAssignmentFailure(
        'Auto assignment failed: missing pickup/dropoff coordinates',
      );
    }

    return AssignmentOrder(
      id: orderId,
      companyId: companyId,
      merchantId: merchantId,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      dropoffType: dropoffType,
      demand: demand,
      createdAt: _parseDate(order['created_at']) ?? DateTime.now().toUtc(),
      timeWindowStart: _firstDate([
        order['time_window_start'],
        order['delivery_window_start'],
        order['preferred_delivery_from'],
      ]),
      timeWindowEnd: _firstDate([
        order['time_window_end'],
        order['delivery_window_end'],
        order['preferred_delivery_until'],
        order['delivery_deadline'],
      ]),
      prioritySeconds: _prioritySeconds(order, dropoffType),
    );
  }

  Future<List<CandidateDriver>> _loadCandidateDrivers(String companyId) async {
    final driverRows = await _db
        .from('drivers')
        .select('*')
        .eq('company_id', companyId)
        .eq('verification_status', 'approved');
    final rows = List<Map<String, dynamic>>.from(driverRows);
    final drivers = <CandidateDriver>[];

    for (final row in rows) {
      if (!_isDriverAvailable(row)) continue;
      final driverId = row['id']?.toString();
      if (driverId == null || driverId.isEmpty) continue;

      drivers.add(
        CandidateDriver(
          id: driverId,
          profileId: row['profile_id']?.toString(),
          companyId: companyId,
          vehicleType: row['vehicle_type']?.toString() ?? 'motorcycle',
          capacity: _driverCapacity(row),
          currentLocation: await _loadDriverLocation(driverId),
          shiftStartAt: _firstDate([
            row['shift_start_at'],
            row['shift_starts_at'],
            row['shift_window_start'],
          ]),
          shiftEndAt: _firstDate([
            row['shift_end_at'],
            row['shift_ends_at'],
            row['shift_window_end'],
          ]),
        ),
      );
    }

    return drivers;
  }

  Future<DriverRoute> _loadDriverRoute(CandidateDriver driver) async {
    final persisted = await _tryLoadPersistedRoute(driver);
    if (persisted != null) {
      return _mergeActiveAssignmentsIntoRoute(driver, persisted);
    }
    return _inferRouteFromAssignments(driver);
  }

  Future<DriverRoute?> _tryLoadPersistedRoute(CandidateDriver driver) async {
    try {
      final routeRow = await _db
          .from('driver_routes')
          .select('id')
          .eq('driver_id', driver.id)
          .eq('status', 'active')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (routeRow == null) return null;

      final stopRows = await _db
          .from('driver_route_stops')
          .select('*')
          .eq('route_id', routeRow['id'].toString())
          .isFilter('completed_at', null)
          .order('sequence_index', ascending: true);
      final rawStops = List<Map<String, dynamic>>.from(stopRows);
      if (rawStops.isEmpty) return _emptyRoute(driver);

      final orderIds = rawStops
          .map((row) => row['order_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final orderMap = await _loadOrdersById(orderIds);
      final stops = <RouteStop>[];
      final loadedOrderIds = <String>{};
      var initialLoad = OrderDemand.zero;

      for (final row in rawStops) {
        final orderId = row['order_id']?.toString();
        if (orderId == null || orderId.isEmpty) continue;
        final order = orderMap[orderId];
        if (order == null) continue;

        final status = order['status']?.toString().toLowerCase() ?? 'created';
        if (_isCompletedStatus(status)) continue;

        final type = _parseStopType(row['stop_type']);
        final demand = _tryOrderDemand(order);
        if (demand == null) continue;
        if (_isLoadedStatus(status) && loadedOrderIds.add(orderId)) {
          initialLoad = initialLoad + demand;
        }
        if (_isLoadedStatus(status) && type == RouteStopType.pickup) {
          continue;
        }

        stops.add(
          RouteStop(
            orderId: orderId,
            type: type,
            location: AssignmentLocation(
              name: row['location_name']?.toString() ?? type.name,
              address: row['location_address']?.toString(),
              lat: _toDouble(row['lat']),
              lng: _toDouble(row['lng']),
            ),
            demand: demand,
            serviceSeconds:
                _toInt(row['service_seconds']) ??
                (type == RouteStopType.pickup ? 5 * 60 : 10 * 60),
            earliestArrivalAt: _parseDate(row['earliest_arrival_at']),
            latestArrivalAt: _parseDate(row['latest_arrival_at']),
          ),
        );
      }

      return DriverRoute(
        driverId: driver.id,
        companyId: driver.companyId,
        currentLocation: driver.currentLocation,
        vehicleCapacity: driver.capacity,
        initialLoad: initialLoad,
        stops: stops,
      );
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<DriverRoute> _inferRouteFromAssignments(CandidateDriver driver) async {
    return _mergeActiveAssignmentsIntoRoute(driver, _emptyRoute(driver));
  }

  Future<DriverRoute> _mergeActiveAssignmentsIntoRoute(
    CandidateDriver driver,
    DriverRoute baseRoute,
  ) async {
    final assignmentRows = await _db
        .from('assignments')
        .select('order_id, assigned_at')
        .eq('driver_id', driver.id)
        .eq('company_id', driver.companyId)
        .isFilter('completed_at', null)
        .order('assigned_at', ascending: true);
    final assignments = List<Map<String, dynamic>>.from(assignmentRows);

    var initialLoad = baseRoute.initialLoad;
    final stops = List<RouteStop>.from(baseRoute.stops);
    final pickupOrderIds = <String>{
      for (final stop in stops)
        if (stop.type == RouteStopType.pickup) stop.orderId,
    };
    final dropoffOrderIds = <String>{
      for (final stop in stops)
        if (stop.type == RouteStopType.dropoff) stop.orderId,
    };
    for (final assignment in assignments) {
      final existingOrderId = assignment['order_id']?.toString();
      if (existingOrderId == null || existingOrderId.isEmpty) continue;

      final existingOrder = await _loadAssignmentOrder(existingOrderId);
      if (existingOrder == null) continue;

      final status = await _loadOrderStatus(existingOrderId);
      if (_isCompletedStatus(status)) continue;
      if (_isLoadedStatus(status)) {
        if (!dropoffOrderIds.contains(existingOrderId)) {
          initialLoad = initialLoad + existingOrder.demand;
          stops.add(existingOrder.dropoffStop());
          dropoffOrderIds.add(existingOrderId);
        }
      } else {
        if (!pickupOrderIds.contains(existingOrderId)) {
          stops.add(existingOrder.pickupStop());
          pickupOrderIds.add(existingOrderId);
        }
        if (!dropoffOrderIds.contains(existingOrderId)) {
          stops.add(existingOrder.dropoffStop());
          dropoffOrderIds.add(existingOrderId);
        }
      }
    }

    return baseRoute.copyWith(
      currentLocation: driver.currentLocation,
      initialLoad: initialLoad,
      stops: stops,
    );
  }

  DriverRoute _emptyRoute(CandidateDriver driver) {
    return DriverRoute(
      driverId: driver.id,
      companyId: driver.companyId,
      currentLocation: driver.currentLocation,
      vehicleCapacity: driver.capacity,
      initialLoad: OrderDemand.zero,
      stops: const [],
    );
  }

  bool _canCarryOrderNow({
    required DriverRoute route,
    required OrderDemand orderDemand,
  }) {
    final currentLoad = route.initialLoad;
    if (!currentLoad.isNonNegative ||
        !currentLoad.fitsWithin(route.vehicleCapacity)) {
      return false;
    }

    final projectedLoad = currentLoad + orderDemand;
    return projectedLoad.isNonNegative &&
        projectedLoad.fitsWithin(route.vehicleCapacity);
  }

  Future<void> _commitAssignment(
    AssignmentOrder order,
    RouteInsertion insertion,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final existingAssignment = await _db
        .from('assignments')
        .select('id')
        .eq('order_id', order.id)
        .limit(1)
        .maybeSingle();

    if (existingAssignment == null) {
      await _db.from('assignments').insert({
        'company_id': order.companyId,
        'order_id': order.id,
        'driver_id': insertion.driver.id,
        'assigned_at': now,
        'accepted_at': null,
        'completed_at': null,
      });
    } else {
      await _db
          .from('assignments')
          .update({
            'company_id': order.companyId,
            'driver_id': insertion.driver.id,
            'assigned_at': now,
            'accepted_at': null,
            'completed_at': null,
          })
          .eq('id', existingAssignment['id'].toString());
    }

    await _db
        .from('orders')
        .update({
          'delivery_company_id': order.companyId,
          'status': 'assigned',
          'updated_at': now,
        })
        .eq('id', order.id);

    await _db.from('order_events').insert({
      'order_id': order.id,
      'event_type': 'assigned_to_driver',
      'created_by': _db.auth.currentUser?.id,
      'note':
          'Automatically assigned by insertion optimizer. Cost: ${insertion.costSeconds.round()} seconds.',
      'metadata': {
        'driver_id': insertion.driver.id,
        'pickup_index': insertion.pickupIndex,
        'dropoff_index': insertion.dropoffIndex,
        'incremental_travel_seconds': insertion.incrementalTravelSeconds,
        'incremental_service_seconds': insertion.incrementalServiceSeconds,
        'incremental_lateness_penalty_seconds':
            insertion.incrementalLatenessPenaltySeconds,
        'cost_seconds': insertion.costSeconds,
      },
    });

    await _persistDriverRoute(insertion.driver, insertion.plannedRoute);
  }

  Future<void> _persistDriverRoute(
    CandidateDriver driver,
    DriverRoute route,
  ) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      var routeRow = await _db
          .from('driver_routes')
          .select('id')
          .eq('driver_id', driver.id)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      if (routeRow == null) {
        routeRow = await _db
            .from('driver_routes')
            .insert({
              'driver_id': driver.id,
              'company_id': driver.companyId,
              'status': 'active',
              'created_at': now,
              'updated_at': now,
            })
            .select('id')
            .single();
      } else {
        await _db
            .from('driver_routes')
            .update({'updated_at': now})
            .eq('id', routeRow['id'].toString());
      }

      final routeId = routeRow['id'].toString();
      await _db.from('driver_route_stops').delete().eq('route_id', routeId);
      final stopRows = await _routeStopRowsWithEtas(
        routeId: routeId,
        driver: driver,
        route: route,
      );
      if (stopRows.isNotEmpty) {
        await _db.from('driver_route_stops').insert(stopRows);
      }
    } on PostgrestException {
      return;
    } catch (_) {
      return;
    }
  }

  Future<List<Map<String, dynamic>>> _routeStopRowsWithEtas({
    required String routeId,
    required CandidateDriver driver,
    required DriverRoute route,
  }) async {
    final rows = <Map<String, dynamic>>[];
    var clock = DateTime.now().toUtc();
    final shiftStart = driver.shiftStartAt;
    if (shiftStart != null && clock.isBefore(shiftStart)) {
      clock = shiftStart;
    }

    var previous = route.currentLocation;
    for (var i = 0; i < route.stops.length; i++) {
      final stop = route.stops[i];
      final travel = await _routingService.getTravelEstimate(
        origin: previous,
        destination: stop.location,
        departureTime: clock,
        vehicleType: driver.vehicleType,
      );
      clock = clock.add(Duration(seconds: travel.durationSeconds));
      final etaAt = clock;
      clock = clock.add(Duration(seconds: stop.serviceSeconds));
      previous = stop.location;

      rows.add({
        'route_id': routeId,
        'driver_id': driver.id,
        'company_id': driver.companyId,
        'order_id': stop.orderId,
        'stop_type': stop.dbType,
        'sequence_index': i,
        'location_name': stop.location.name,
        'location_address': stop.location.address,
        'lat': stop.location.lat,
        'lng': stop.location.lng,
        'service_seconds': stop.serviceSeconds,
        'eta_at': etaAt.toIso8601String(),
        'earliest_arrival_at': stop.earliestArrivalAt?.toIso8601String(),
        'latest_arrival_at': stop.latestArrivalAt?.toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    return rows;
  }

  Future<void> _recordUnassignedEvent(String orderId, String reason) async {
    if (orderId == 'unknown') return;
    try {
      await _db.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'note_added',
        'created_by': _db.auth.currentUser?.id,
        'note': reason,
        'metadata': {'assignment_status': 'unassigned'},
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _loadById(String table, dynamic id) async {
    final stringId = id?.toString();
    if (stringId == null || stringId.isEmpty) return null;
    try {
      return await _db.from(table).select('*').eq('id', stringId).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadOrderAddress(String orderId) async {
    try {
      return await _db
          .from('order_addresses')
          .select('*')
          .eq('order_id', orderId)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadOrdersById(
    List<String> orderIds,
  ) async {
    if (orderIds.isEmpty) return {};
    final rows = await _db.from('orders').select('*').inFilter('id', orderIds);
    return {
      for (final row in List<Map<String, dynamic>>.from(rows))
        if (row['id'] != null) row['id'].toString(): row,
    };
  }

  Future<String> _loadOrderStatus(String orderId) async {
    final row = await _db
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .limit(1)
        .maybeSingle();
    return row?['status']?.toString().toLowerCase() ?? 'created';
  }

  Future<String?> _resolveActiveCompanyIdForMerchant(String merchantId) async {
    try {
      final rows = await _db
          .from('merchant_delivery_companies')
          .select('company_id')
          .eq('merchant_id', merchantId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1);
      final mappings = List<Map<String, dynamic>>.from(rows);
      if (mappings.isEmpty) return null;
      return mappings.first['company_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureOrderCompany({
    required String orderId,
    required String companyId,
  }) async {
    try {
      await _db
          .from('orders')
          .update({
            'delivery_company_id': companyId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (_) {}
  }

  Future<AssignmentLocation> _loadDriverLocation(String driverId) async {
    try {
      final row = await _db
          .from('driver_locations')
          .select('*')
          .eq('driver_id', driverId)
          .maybeSingle();
      if (row == null) return AssignmentLocation.unknown('Driver $driverId');
      return AssignmentLocation(
        name: row['city']?.toString() ?? 'Driver $driverId',
        address: row['address_text']?.toString() ?? row['city']?.toString(),
        lat: _toDouble(row['lat']),
        lng: _toDouble(row['lng']),
      );
    } catch (_) {
      return AssignmentLocation.unknown('Driver $driverId');
    }
  }

  AssignmentLocation _pickupLocation(
    Map<String, dynamic> order,
    Map<String, dynamic>? branch,
    Map<String, dynamic>? pickupPoint,
    Map<String, dynamic>? address,
  ) {
    if (branch != null) {
      return AssignmentLocation(
        name: branch['name']?.toString() ?? 'Merchant branch',
        address: branch['address_text']?.toString(),
        lat: _toDouble(branch['lat']),
        lng: _toDouble(branch['lng']),
      );
    }

    if (pickupPoint != null) {
      return AssignmentLocation(
        name: pickupPoint['name']?.toString() ?? 'Pickup point',
        address: pickupPoint['address_text']?.toString(),
        lat: _toDouble(pickupPoint['lat']),
        lng: _toDouble(pickupPoint['lng']),
      );
    }

    return AssignmentLocation(
      name: order['merchant_name']?.toString() ?? 'Merchant pickup',
      address:
          address?['pickup_address_text']?.toString() ??
          order['pickup_address_text']?.toString(),
      lat: _toDouble(address?['pickup_lat'] ?? order['pickup_lat']),
      lng: _toDouble(address?['pickup_lng'] ?? order['pickup_lng']),
    );
  }

  AssignmentLocation _dropoffLocation(
    Map<String, dynamic> order,
    Map<String, dynamic>? address,
    Map<String, dynamic>? pickupPoint,
    DropoffType dropoffType,
  ) {
    if (dropoffType == DropoffType.pickupPoint && pickupPoint != null) {
      return AssignmentLocation(
        name: pickupPoint['name']?.toString() ?? 'Pickup point dropoff',
        address: pickupPoint['address_text']?.toString(),
        lat: _toDouble(pickupPoint['lat']),
        lng: _toDouble(pickupPoint['lng']),
      );
    }

    return AssignmentLocation(
      name: order['customer_name']?.toString() ?? 'Customer dropoff',
      address: _firstNonEmpty([
        address?['dropoff_address_text'],
        address?['dropoff_address'],
        order['customer_address_text'],
        order['dropoff_address_text'],
      ]),
      lat: _toDouble(address?['dropoff_lat'] ?? order['dropoff_lat']),
      lng: _toDouble(address?['dropoff_lng'] ?? order['dropoff_lng']),
    );
  }

  DropoffType _parseDropoffType(Map<String, dynamic> order) {
    final raw = order['dropoff_type']?.toString().toLowerCase();
    if (raw == 'pickup_point' || raw == 'pickup point') {
      return DropoffType.pickupPoint;
    }
    return order['pickup_point_id'] == null
        ? DropoffType.home
        : DropoffType.pickupPoint;
  }

  RouteStopType _parseStopType(dynamic raw) {
    return raw?.toString().toLowerCase() == 'dropoff'
        ? RouteStopType.dropoff
        : RouteStopType.pickup;
  }

  OrderDemand? _tryOrderDemand(Map<String, dynamic> row) {
    try {
      final normalizedDemand = DeliveryConstraintDefaults.normalizeOrderDemand(
        itemCount: _toInt(row['item_count'] ?? row['items_count']),
        weightKg: _toDouble(
          row['estimated_weight'] ?? row['estimated_weight_kg'],
        ),
        volumeCm3: _toDouble(
          row['estimated_volume'] ?? row['estimated_volume_cm3'],
        ),
      );
      return OrderDemand(
        weightKg: normalizedDemand.weightKg,
        volumeCm3: normalizedDemand.volumeCm3,
        itemCount: normalizedDemand.itemCount,
      );
    } on ArgumentError {
      return null;
    }
  }

  OrderDemand _driverCapacity(Map<String, dynamic> row) {
    final defaults = _defaultCapacity(row['vehicle_type']?.toString());
    final weightKg = _toDouble(row['capacity_weight']);
    final volumeCm3 = _toDouble(row['capacity_volume']);
    final itemCount = _toInt(row['capacity_item_count']);

    if (weightKg == null || volumeCm3 == null || itemCount == null) {
      developer.log(
        'Driver ${row['id'] ?? row['profile_id'] ?? 'unknown'} is missing stored capacity data. '
        'Using vehicle defaults as a safety fallback only.',
        name: 'OrderAssignmentService',
        level: 900,
      );
    }

    return OrderDemand(
      weightKg: weightKg ?? defaults.weightKg,
      volumeCm3: volumeCm3 ?? defaults.volumeCm3,
      itemCount: itemCount ?? defaults.itemCount,
    );
  }

  OrderDemand _defaultCapacity(String? vehicleType) {
    final capacity = DeliveryConstraintDefaults.capacityForVehicleType(
      vehicleType,
    );
    return OrderDemand(
      weightKg: capacity.weightKg,
      volumeCm3: capacity.volumeCm3,
      itemCount: capacity.itemCount,
    );
  }

  int _prioritySeconds(Map<String, dynamic> order, DropoffType dropoffType) {
    final basePriority = dropoffType == DropoffType.home ? 8 * 60 : 3 * 60;
    final raw = order['priority'];
    if (raw is num) return math.max(basePriority, raw.round() * 60);

    switch (raw?.toString().toLowerCase()) {
      case 'urgent':
        return 20 * 60;
      case 'high':
        return 12 * 60;
      case 'normal':
        return basePriority;
      case 'low':
        return 60;
      default:
        return basePriority;
    }
  }

  bool _isDriverAvailable(Map<String, dynamic> row) {
    final isActive = row['is_active'];
    if (isActive is bool && !isActive) return false;

    final status = row['availability_status']?.toString().toLowerCase();
    if (status == null || status.isEmpty) return true;
    return const {'available', 'active', 'online', 'idle'}.contains(status);
  }

  bool _isLoadedStatus(String status) {
    return const {
      'picked_up',
      'driver_received_order',
      'in_transit',
      'returning_to_store',
    }.contains(status.toLowerCase());
  }

  bool _isCompletedStatus(String status) {
    return const {
      'delivered',
      'dropped_at_pickup_point',
      'returned_to_store',
      'cancelled',
    }.contains(status.toLowerCase());
  }

  String? _extractOrderId(Map<String, dynamic> response) {
    final nestedOrder = response['order'];
    if (nestedOrder is Map) {
      final nestedId = _firstNonEmpty([
        nestedOrder['id'],
        nestedOrder['order_id'],
      ]);
      if (nestedId != null) return nestedId;
    }

    final nestedData = response['data'];
    if (nestedData is Map) {
      final nestedId = _extractOrderId(Map<String, dynamic>.from(nestedData));
      if (nestedId != null) return nestedId;
    }

    return _firstNonEmpty([
      response['order_id'],
      response['id'],
      response['orderId'],
    ]);
  }

  DateTime? _firstDate(List<dynamic> values) {
    for (final value in values) {
      final parsed = _parseDate(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != '-') return text;
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }
}

class _AutoAssignmentFailure implements Exception {
  final String message;

  const _AutoAssignmentFailure(this.message);

  @override
  String toString() => message;
}
