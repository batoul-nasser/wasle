import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/domain/delivery_constraints.dart';
import 'package:wasle/core/services/supabase_service.dart';

import 'assignment_models.dart';
import 'route_insertion_engine.dart';
import 'routing_service.dart';

class OrderAssignmentService {
  static const Duration _freshLocationWindow = Duration(minutes: 3);

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
        await _recordUnassignedEvent(
          orderId,
          'Order not found or missing company, package, or routing data.',
        );
        return AssignmentResult.unassigned(
          orderId: orderId,
          reason:
              'Order not found or missing company, package, or routing data.',
          testedDrivers: 0,
          feasibleInsertions: 0,
        );
      }

      final load = await _loadCandidateDrivers(
        order.companyId,
        orderPickup: order.pickupLocation,
      );
      final drivers = load.drivers;
      testedDrivers = drivers.length;
      _debug(
        'Auto-assign start order=${order.id} company=${order.companyId} '
        'pickup=${order.pickupLocation.lat},${order.pickupLocation.lng} '
        'dropoff=${order.dropoffLocation.lat},${order.dropoffLocation.lng} '
        'candidates=$testedDrivers',
      );
      if (drivers.isEmpty) {
        final reason = load.emptyPoolDetail == null
            ? 'No approved drivers are linked to this company (or none passed verification).'
            : 'No driver is ready for automatic assignment. ${load.emptyPoolDetail} '
                'Tip: auto-assign uses driver GPS when present, otherwise company base or '
                'order pickup for routing; drivers with active deliveries are still considered '
                'as long as route/capacity insertion is feasible. '
                'You can still assign manually from the list.';
        await _recordUnassignedEvent(order.id, reason);
        return AssignmentResult.unassigned(
          orderId: order.id,
          reason: reason,
          testedDrivers: testedDrivers,
          feasibleInsertions: 0,
        );
      }

      RouteInsertion? bestInsertion;
      final candidateFailureNotes = <String>[];

      void noteCandidateFailure(String line) {
        const maxNotes = 4;
        const maxLen = 120;
        if (candidateFailureNotes.length >= maxNotes) return;
        final trimmed =
            line.length > maxLen ? '${line.substring(0, maxLen - 1)}…' : line;
        candidateFailureNotes.add(trimmed);
      }

      String shortDriverId(String id) =>
          id.length <= 10 ? id : '${id.substring(0, 10)}…';

      for (final driver in drivers) {
        try {
          final route = await _loadDriverRoute(driver);
          if (!_canCarryOrderNow(route: route, orderDemand: order.demand)) {
            _debug(
              explainDriverRejection(
                driverId: driver.id,
                reason: 'capacity_insufficient',
                details:
                    'current_load=${route.initialLoad.itemCount}/${route.initialLoad.weightKg.toStringAsFixed(1)}kg '
                    'order=${order.demand.itemCount}/${order.demand.weightKg.toStringAsFixed(1)}kg '
                    'capacity=${driver.capacity.itemCount}/${driver.capacity.weightKg.toStringAsFixed(1)}kg',
              ),
            );
            noteCandidateFailure(
              '${shortDriverId(driver.id)}: capacity — current load '
              '${route.initialLoad.itemCount} items / '
              '${route.initialLoad.weightKg.toStringAsFixed(1)} kg + order '
              '${order.demand.itemCount} / ${order.demand.weightKg.toStringAsFixed(1)} kg '
              'vs vehicle cap ${driver.capacity.itemCount} / '
              '${driver.capacity.weightKg.toStringAsFixed(1)} kg',
            );
            continue;
          }

          final driverToPickup = await _routingService.getTravelEstimate(
            origin: driver.currentLocation,
            destination: order.pickupLocation,
            departureTime: DateTime.now().toUtc(),
            vehicleType: driver.vehicleType,
          );
          final pickupToDropoff = await _routingService.getTravelEstimate(
            origin: order.pickupLocation,
            destination: order.dropoffLocation,
            departureTime: DateTime.now().toUtc(),
            vehicleType: driver.vehicleType,
          );
          _debug(
            'Candidate ${driver.id} route preview '
            'driver->pickup=${driverToPickup.distanceMeters.toStringAsFixed(0)}m/${driverToPickup.durationSeconds}s '
            'pickup->dropoff=${pickupToDropoff.distanceMeters.toStringAsFixed(0)}m/${pickupToDropoff.durationSeconds}s '
            'shiftStart=${driver.shiftStartAt?.toIso8601String()} '
            'shiftEnd=${driver.shiftEndAt?.toIso8601String()}',
          );

          final insertion = await _insertionEngine.findBestInsertion(
            driver: driver,
            route: route,
            order: order,
          );
          if (insertion == null) {
            _debug(
              explainDriverRejection(
                driverId: driver.id,
                reason: 'route_insertion_not_feasible',
                details:
                    'shift_start=${driver.shiftStartAt?.toIso8601String()} '
                    'shift_end=${driver.shiftEndAt?.toIso8601String()} '
                    'stops=${route.stops.length} '
                    'demand=${order.demand.itemCount}i/${order.demand.weightKg.toStringAsFixed(1)}kg '
                    '${order.demand.volumeCm3.toStringAsFixed(0)}cm3 '
                    'cap=${driver.capacity.itemCount}i/${driver.capacity.weightKg.toStringAsFixed(1)}kg/'
                    '${driver.capacity.volumeCm3.toStringAsFixed(0)}cm3',
              ),
            );
            final shiftLabel = (driver.shiftStartAt == null &&
                    driver.shiftEndAt == null)
                ? 'open'
                : '${driver.shiftStartAt?.toIso8601String() ?? "?"}→${driver.shiftEndAt?.toIso8601String() ?? "?"}';
            noteCandidateFailure(
              '${shortDriverId(driver.id)}: no route slot — '
              'shifts $shiftLabel stops=${route.stops.length}',
            );
            continue;
          }

          feasibleInsertions += insertion.feasibleInsertionCount;
          _debug(
            'Candidate ${driver.id} feasible '
            'cost=${insertion.costSeconds.toStringAsFixed(1)} '
            'travel+service=${insertion.incrementalTravelSeconds + insertion.incrementalServiceSeconds}s '
            'lateness_penalty=${insertion.incrementalLatenessPenaltySeconds}s',
          );
          if (bestInsertion == null ||
              insertion.costSeconds < bestInsertion.costSeconds) {
            bestInsertion = insertion;
          }
        } catch (error) {
          final classified = _classifyAutoAssignDriverLoopError(error);
          _debug(
            explainDriverRejection(
              driverId: driver.id,
              reason: classified,
              details: error.toString(),
            ),
          );
          final errBrief = error.toString();
          noteCandidateFailure(
            '${shortDriverId(driver.id)}: $classified — '
            '${errBrief.length > 90 ? "${errBrief.substring(0, 90)}…" : errBrief}',
          );
          continue;
        }
      }

      if (bestInsertion == null) {
        const base =
            'No feasible driver found after capacity, shift, and route checks.';
        final reason = candidateFailureNotes.isEmpty
            ? base
            : '$base Notes: ${candidateFailureNotes.join(' | ')}';
        await _recordUnassignedEvent(order.id, reason);
        return AssignmentResult.unassigned(
          orderId: order.id,
          reason: reason.length > 420 ? '${reason.substring(0, 417)}...' : reason,
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
    /// When building a driver's route from older [assignments], skip bad rows
    /// instead of throwing so one incomplete legacy order does not block
    /// auto-assign for a new order.
    bool allowIncomplete = false,
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
    final destinationPickupPoint = await _loadById(
      'pickup_points',
      order['destination_pickup_point_id'],
    );
    final address = await _loadOrderAddress(orderId);
    final dropoffType = _parseDropoffType(order);
    final demand = _tryOrderDemand(order);
    if (demand == null) {
      if (allowIncomplete) return null;
      throw const _AutoAssignmentFailure(
        'Auto assignment failed: missing package demand',
      );
    }

    final pickupLocation = _pickupLocation(order, branch, pickupPoint, address);
    final dropoffLocation = _dropoffLocation(
      order,
      address,
      destinationPickupPoint ?? pickupPoint,
      dropoffType,
    );
    if (!pickupLocation.hasCoordinates || !dropoffLocation.hasCoordinates) {
      if (allowIncomplete) return null;
      throw const _AutoAssignmentFailure(
        'Auto assignment failed: missing pickup/dropoff coordinates',
      );
    }

    final resolvedTimeWindow = _resolveOrderTimeWindow(order);

    return AssignmentOrder(
      id: orderId,
      companyId: companyId,
      merchantId: merchantId,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      dropoffType: dropoffType,
      demand: demand,
      createdAt: _parseDate(order['created_at']) ?? DateTime.now().toUtc(),
      timeWindowStart: resolvedTimeWindow?.$1,
      timeWindowEnd: resolvedTimeWindow?.$2,
      prioritySeconds: _prioritySeconds(order, dropoffType),
    );
  }

  (DateTime?, DateTime?)? _resolveOrderTimeWindow(Map<String, dynamic> order) {
    final explicitStart = _firstDate([
      order['time_window_start'],
      order['delivery_window_start'],
      order['preferred_delivery_from'],
    ]);
    final explicitEnd = _firstDate([
      order['time_window_end'],
      order['delivery_window_end'],
      order['preferred_delivery_until'],
      order['delivery_deadline'],
    ]);

    if (explicitStart != null || explicitEnd != null) {
      return (explicitStart, explicitEnd);
    }

    final direct = _firstNonEmpty([
      order['preferred_time_window'],
      order['preferredTimeWindow'],
    ]);
    if (direct == null) return null;
    return _parsePreferredTimeWindow(direct);
  }

  (DateTime?, DateTime?)? _parsePreferredTimeWindow(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;

    final nowLocal = DateTime.now();
    final rangePattern = RegExp(
      r'(.+?)\s*(?:-|to|until|->|–)\s*(.+)',
      caseSensitive: false,
    );
    final rangeMatch = rangePattern.firstMatch(value);
    if (rangeMatch != null) {
      final startMinutes = _parseClockMinutes(rangeMatch.group(1)!);
      final endMinutes = _parseClockMinutes(rangeMatch.group(2)!);
      if (startMinutes == null || endMinutes == null) return null;
      final start = _nextLocalDateTimeForClock(nowLocal, startMinutes);
      var end = _localDateTimeForClock(start, endMinutes);
      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }
      return (start.toUtc(), end.toUtc());
    }

    final singleMinutes = _parseClockMinutes(value);
    if (singleMinutes == null) return null;
    final when = _nextLocalDateTimeForClock(nowLocal, singleMinutes).toUtc();
    // Exact preferred time with a short tolerance window.
    return (when, when.add(const Duration(minutes: 30)));
  }

  int? _parseClockMinutes(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;

    final ampmPattern = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m?\.?$');
    final ampm = ampmPattern.firstMatch(text);
    if (ampm != null) {
      final hourRaw = int.tryParse(ampm.group(1)!);
      final minuteRaw = int.tryParse(ampm.group(2) ?? '0');
      final marker = ampm.group(3);
      if (hourRaw == null ||
          minuteRaw == null ||
          hourRaw < 1 ||
          hourRaw > 12 ||
          minuteRaw < 0 ||
          minuteRaw > 59 ||
          marker == null) {
        return null;
      }
      var hour24 = hourRaw % 12;
      if (marker == 'p') hour24 += 12;
      return hour24 * 60 + minuteRaw;
    }

    final hhmmPattern = RegExp(r'^(\d{1,2})(?::(\d{2}))$');
    final hhmm = hhmmPattern.firstMatch(text);
    if (hhmm != null) {
      final hour = int.tryParse(hhmm.group(1)!);
      final minute = int.tryParse(hhmm.group(2)!);
      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        return null;
      }
      return hour * 60 + minute;
    }

    // Accept simple hour values like "4pm" already handled above, and "16".
    final hourOnly = int.tryParse(text);
    if (hourOnly == null || hourOnly < 0 || hourOnly > 23) return null;
    return hourOnly * 60;
  }

  DateTime _nextLocalDateTimeForClock(DateTime nowLocal, int minutes) {
    final candidate = _localDateTimeForClock(nowLocal, minutes);
    if (!candidate.isBefore(nowLocal)) return candidate;
    return candidate.add(const Duration(days: 1));
  }

  DateTime _localDateTimeForClock(DateTime date, int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  Future<AssignmentLocation?> _companyDepotLocation(String companyId) async {
    try {
      final row = await _db
          .from('delivery_companies')
          .select('lat,lng,latitude,longitude,name')
          .eq('id', companyId)
          .maybeSingle();
      if (row == null) return null;
      final lat = _toDouble(row['lat']) ?? _toDouble(row['latitude']);
      final lng = _toDouble(row['lng']) ?? _toDouble(row['longitude']);
      if (lat == null || lng == null) return null;
      final rawName = row['name']?.toString().trim();
      final label = (rawName != null && rawName.isNotEmpty)
          ? '$rawName (company base)'
          : 'Company base';
      return AssignmentLocation(
        name: label,
        address: null,
        lat: lat,
        lng: lng,
      );
    } catch (_) {
      return null;
    }
  }

  /// Matches [AuthService.getApprovedDriversForCurrentCompany]: rows without a
  /// [profile_id] never appear in the company UI. Duplicate [drivers] rows for
  /// the same profile (re-signups) collapse to the newest row so auto-assign
  /// does not count one person as four drivers.
  ({List<Map<String, dynamic>> rows, int skippedMissingProfile})
  _dedupeDriverRowsForAutoAssignPool(List<Map<String, dynamic>> merged) {
    var skippedMissingProfile = 0;
    final byProfile = <String, Map<String, dynamic>>{};
    for (final row in merged) {
      final profileKey = row['profile_id']?.toString().trim();
      if (profileKey == null || profileKey.isEmpty) {
        skippedMissingProfile++;
        continue;
      }
      final existing = byProfile[profileKey];
      if (existing == null) {
        byProfile[profileKey] = row;
        continue;
      }
      final tExisting = _firstDate([existing['updated_at']]) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final tRow = _firstDate([row['updated_at']]) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      byProfile[profileKey] = tRow.isAfter(tExisting) ? row : existing;
    }
    return (rows: byProfile.values.toList(), skippedMissingProfile: skippedMissingProfile);
  }

  Future<
      ({
        List<CandidateDriver> drivers,
        String? emptyPoolDetail,
      })> _loadCandidateDrivers(
    String companyId, {
    required AssignmentLocation orderPickup,
  }) async {
    final approvedRequestRows = await _db
        .from('driver_company_requests')
        .select('driver_profile_id')
        .eq('company_id', companyId)
        .eq('request_status', 'approved');
    final approvedProfileIds = List<Map<String, dynamic>>.from(approvedRequestRows)
        .map((row) => row['driver_profile_id']?.toString().trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final rowsByCompany = List<Map<String, dynamic>>.from(
      await _db.from('drivers').select('*').eq('company_id', companyId),
    );
    final rowsByProfile = approvedProfileIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _db
                .from('drivers')
                .select('*')
                .inFilter('profile_id', approvedProfileIds),
          );

    final rowByDriverId = <String, Map<String, dynamic>>{};
    for (final row in [...rowsByCompany, ...rowsByProfile]) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      rowByDriverId[id] = row;
    }
    final merged = rowByDriverId.values.toList();
    final deduped = _dedupeDriverRowsForAutoAssignPool(merged);
    final rows = deduped.rows;
    final skippedMissingProfile = deduped.skippedMissingProfile;
    _debug(
      'Candidate pool for company=$companyId: '
      'linked=${rowsByCompany.length}, approved_profile_matches=${rowsByProfile.length}, '
      'merged_driver_rows=${merged.length}, unique_profiles=${rows.length}, '
      'skipped_missing_profile=$skippedMissingProfile',
    );
    final drivers = <CandidateDriver>[];
    var skippedCompanyMismatch = 0;
    var skippedNotApproved = 0;
    var skippedAvailability = 0;
    var skippedNoFreshLocation = 0;

    final companyDepot = await _companyDepotLocation(companyId);
    final pickupRoutingProxy = orderPickup.hasCoordinates
        ? AssignmentLocation(
            name: 'Order pickup (driver location unknown)',
            address: orderPickup.address,
            lat: orderPickup.lat,
            lng: orderPickup.lng,
          )
        : null;

    for (final row in rows) {
      final driverId = row['id']?.toString();
      if (driverId == null || driverId.isEmpty) {
        _debug('Reject candidate: missing driver id');
        continue;
      }

      final driverCompanyId = row['company_id']?.toString();
      final profileId = row['profile_id']?.toString().trim();
      final approvedViaRequest =
          profileId != null &&
          profileId.isNotEmpty &&
          approvedProfileIds.contains(profileId);
      if ((driverCompanyId == null || driverCompanyId != companyId) &&
          !approvedViaRequest) {
        skippedCompanyMismatch++;
        _debug(
          explainDriverRejection(
            driverId: driverId,
            reason: 'company_mismatch',
            details:
                'order_company=$companyId driver_company=$driverCompanyId '
                'profile_id=$profileId approved_via_request=$approvedViaRequest',
          ),
        );
        continue;
      }

      final verificationStatus = row['verification_status']
          ?.toString()
          .trim()
          .toLowerCase();
      if (verificationStatus != 'approved') {
        skippedNotApproved++;
        _debug(
          explainDriverRejection(
            driverId: driverId,
            reason: 'not_approved',
            details: 'verification_status=$verificationStatus',
          ),
        );
        continue;
      }

      if (!_isDriverAssignableForAutoAssign(row)) {
        skippedAvailability++;
        _debug(
          explainDriverRejection(
            driverId: driverId,
            reason: 'unavailable',
            details:
                'availability_status=${row['availability_status']} '
                'is_available=${row['is_available']} '
                'is_active_shift=${row['is_active_shift']}',
          ),
        );
        continue;
      }

      var location = await _loadFreshDriverLocation(
        driverId,
        row,
        allowCoordsWithoutPing: true,
        allowStaleCoordinates: true,
      );
      if (location == null &&
          companyDepot != null &&
          companyDepot.hasCoordinates) {
        location = companyDepot;
        _debug(
          '[auto-assign] driver=$driverId using company depot as routing origin '
          '(no driver GPS).',
        );
      }
      if (location == null &&
          pickupRoutingProxy != null &&
          pickupRoutingProxy.hasCoordinates) {
        location = pickupRoutingProxy;
        _debug(
          '[auto-assign] driver=$driverId using order pickup as routing origin '
          '(no driver GPS or company base on map).',
        );
      }
      if (location == null) {
        skippedNoFreshLocation++;
        _debug(
          explainDriverRejection(
            driverId: driverId,
            reason: 'no_location',
            details:
                'no driver coordinates, company depot=${companyDepot != null}, '
                'pickup_ok=${pickupRoutingProxy != null}',
          ),
        );
        continue;
      }

      drivers.add(
        CandidateDriver(
          id: driverId,
          profileId: profileId,
          companyId: companyId,
          vehicleType: row['vehicle_type']?.toString() ?? 'motorcycle',
          capacity: _driverCapacity(row),
          currentLocation: location,
          shiftStartAt: _firstDate([
            row['shift_started_at'],
            row['shift_start_at'],
            row['shift_starts_at'],
            row['shift_window_start'],
          ]),
          shiftEndAt: _firstDate([
            row['shift_ended_at'],
            row['shift_end_at'],
            row['shift_ends_at'],
            row['shift_window_end'],
          ]),
        ),
      );
      _debug(
        'Accept candidate driver=$driverId company=$driverCompanyId '
        'profile_id=$profileId approved_via_request=$approvedViaRequest '
        'lat=${location.lat} lng=${location.lng}',
      );
    }

    String? emptyPoolDetail;
    if (drivers.isEmpty && merged.isNotEmpty) {
      if (rows.isEmpty) {
        emptyPoolDetail =
            'Merged ${merged.length} driver row(s) for this company but none '
            'had a usable profile_id for auto-assign '
            '(ignored: $skippedMissingProfile). '
            'Fix duplicate driver rows or set profile_id to match the approved-drivers list.';
      } else {
        emptyPoolDetail =
            'From ${rows.length} unique driver profile(s) for this company '
            '(after merging duplicate driver rows): '
            'not approved $skippedNotApproved, company/profile mismatch '
            '$skippedCompanyMismatch, blocked/off shift $skippedAvailability, '
            'no map anchor (driver + company + pickup) $skippedNoFreshLocation, '
            'ignored (no profile_id) $skippedMissingProfile.';
      }
    }

    return (drivers: drivers, emptyPoolDetail: emptyPoolDetail);
  }

  Future<DriverRoute> _loadDriverRoute(CandidateDriver driver) async {
    final persisted = await _tryLoadPersistedRoute(driver);
    if (persisted != null) {
      final merged = await _mergeActiveAssignmentsIntoRoute(driver, persisted);
      if (_isRouteStructurallyUsable(merged)) {
        return merged;
      }
      _debug(
        '[auto-assign] driver=${driver.id} persisted route is structurally invalid; '
        'falling back to assignments-only reconstruction.',
      );
    }
    return _inferRouteFromAssignments(driver);
  }

  bool _isRouteStructurallyUsable(DriverRoute route) {
    var load = route.initialLoad;
    if (!load.isNonNegative || !load.fitsWithin(route.vehicleCapacity)) {
      return false;
    }
    for (final stop in route.stops) {
      if (!stop.location.hasCoordinates) return false;
      load = load + stop.loadDelta;
      if (!load.isNonNegative || !load.fitsWithin(route.vehicleCapacity)) {
        return false;
      }
    }
    return true;
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

      // Guard against stale persisted route stops: only keep stops whose order
      // is still in an open assignment for this same driver/company.
      final activeAssignmentRows = await _db
          .from('assignments')
          .select('order_id')
          .eq('driver_id', driver.id)
          .eq('company_id', driver.companyId)
          .isFilter('completed_at', null);
      final activeAssignmentOrderIds = List<Map<String, dynamic>>.from(
        activeAssignmentRows,
      )
          .map((row) => row['order_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      if (activeAssignmentOrderIds.isEmpty) {
        return _emptyRoute(driver);
      }

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
        if (!activeAssignmentOrderIds.contains(orderId)) continue;
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

      final existingOrder = await _loadAssignmentOrder(
        existingOrderId,
        allowIncomplete: true,
      );
      if (existingOrder == null) {
        _debug(
          '[auto-assign] skip open assignment order=$existingOrderId '
          'for driver=${driver.id}: missing demand or pickup/dropoff coordinates',
        );
        continue;
      }

      final status = await _loadOrderStatus(existingOrderId);
      if (_isRouteInactiveStatus(status)) continue;
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
          'company_id': order.companyId,
          'status': 'assigned',
          'assignment_status': 'assigned',
          'assigned_driver_id': insertion.driver.id,
          'assignment_failure_reason': null,
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
    await _updateDriverLoadSnapshot(
      driverId: insertion.driver.id,
      load: insertion.plannedRoute.initialLoad,
    );
  }

  Future<void> _updateDriverLoadSnapshot({
    required String driverId,
    required OrderDemand load,
  }) async {
    try {
      await _db
          .from('drivers')
          .update({
            'current_load_weight': load.weightKg,
            'current_load_volume': load.volumeCm3,
            'current_load_item_count': load.itemCount,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', driverId);
    } catch (_) {}
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
      await _markAssignmentFailed(orderId, reason);
      await _db.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'note_added',
        'created_by': _db.auth.currentUser?.id,
        'note': reason,
        'metadata': {'assignment_status': 'assignment_failed'},
      });
    } catch (_) {}
  }

  Future<void> _markAssignmentFailed(String orderId, String reason) async {
    try {
      final order = await _db
          .from('orders')
          .select('assignment_status, assigned_driver_id')
          .eq('id', orderId)
          .maybeSingle();
      final assignmentStatus = order?['assignment_status']
          ?.toString()
          .trim()
          .toLowerCase();
      final assignedDriverId = order?['assigned_driver_id']?.toString().trim();
      if (assignmentStatus == 'assigned' &&
          assignedDriverId != null &&
          assignedDriverId.isNotEmpty) {
        _debug(
          '[auto-assign] skip marking failed for order=$orderId '
          'because it is already assigned to driver=$assignedDriverId',
        );
        return;
      }

      final existingAssignment = await _db
          .from('assignments')
          .select('id, driver_id')
          .eq('order_id', orderId)
          .isFilter('completed_at', null)
          .limit(1)
          .maybeSingle();
      final assignmentDriverId = existingAssignment?['driver_id']
          ?.toString()
          .trim();
      if (assignmentDriverId != null && assignmentDriverId.isNotEmpty) {
        _debug(
          '[auto-assign] skip marking failed for order=$orderId '
          'because an active assignment exists for driver=$assignmentDriverId',
        );
        return;
      }

      await _db
          .from('orders')
          .update({
            'status': 'pending',
            'assignment_status': 'assignment_failed',
            'assigned_driver_id': null,
            'assignment_failure_reason': reason,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);
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
    final status = await _loadOrderStatusNullable(orderId);
    return status ?? 'created';
  }

  Future<String?> _loadOrderStatusNullable(String orderId) async {
    final row = await _db
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .limit(1)
        .maybeSingle();
    final raw = row?['status']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.toLowerCase();
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
            'company_id': companyId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (_) {}
  }

  Future<AssignmentLocation?> _loadFreshDriverLocation(
    String driverId,
    Map<String, dynamic> driverRow, {
    Duration? maxLocationAge,
    /// When true (auto-assign only), use [current_location_lat]/lng even if
    /// there is no ping timestamp — many rows only have coordinates.
    bool allowCoordsWithoutPing = false,
    /// When true (auto-assign candidate pool only), accept last known coordinates
    /// even if the ping timestamp is stale. Other callers keep a freshness window.
    bool allowStaleCoordinates = false,
  }) async {
    final maxAge = maxLocationAge ?? _freshLocationWindow;
    final rowPing = _firstDate([
      driverRow['last_location_ping_at'],
      driverRow['updated_at'],
    ]);
    final rowLat = _toDouble(driverRow['current_location_lat']);
    final rowLng = _toDouble(driverRow['current_location_lng']);
    if (rowLat != null && rowLng != null) {
      if (allowStaleCoordinates) {
        _debug(
          'Candidate $driverId: using drivers.current_location_* '
          '(last known; ping=${rowPing?.toIso8601String() ?? "none"})',
        );
        return AssignmentLocation(
          name: 'Driver $driverId',
          address: null,
          lat: rowLat,
          lng: rowLng,
        );
      }
      final pingMissing = rowPing == null;
      if (!_isFreshPing(rowPing, maxAge: maxAge)) {
        if (allowCoordsWithoutPing && pingMissing) {
          _debug(
            'Candidate $driverId: using drivers.current_location_* without ping time.',
          );
          return AssignmentLocation(
            name: 'Driver $driverId',
            address: null,
            lat: rowLat,
            lng: rowLng,
          );
        }
        _debug(
          explainDriverRejection(
            driverId: driverId,
            reason: 'stale_location',
            details: 'source=drivers updated_at=${driverRow['updated_at']}',
          ),
        );
        return null;
      }
      return AssignmentLocation(
        name: 'Driver $driverId',
        address: null,
        lat: rowLat,
        lng: rowLng,
      );
    }

    try {
      final row = await _db
          .from('driver_locations')
          .select('*')
          .eq('driver_id', driverId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final pingAt = _firstDate([
        row['last_location_ping_at'],
        row['updated_at'],
      ]);
      final lat = _toDouble(row['lat']);
      final lng = _toDouble(row['lng']);
      if (lat == null || lng == null) return null;
      if (allowStaleCoordinates) {
        _debug(
          'Candidate $driverId: using driver_locations (last known; '
          'ping=${pingAt?.toIso8601String() ?? "none"})',
        );
        return AssignmentLocation(
          name: row['city']?.toString() ?? 'Driver $driverId',
          address: row['address_text']?.toString() ?? row['city']?.toString(),
          lat: lat,
          lng: lng,
        );
      }
      if (!_isFreshPing(pingAt, maxAge: maxAge)) {
        if (allowCoordsWithoutPing && pingAt == null) {
          _debug(
            'Candidate $driverId: using driver_locations lat/lng without ping time.',
          );
          return AssignmentLocation(
            name: row['city']?.toString() ?? 'Driver $driverId',
            address: row['address_text']?.toString() ?? row['city']?.toString(),
            lat: lat,
            lng: lng,
          );
        }
        _debug(
          explainDriverRejection(
            driverId: driverId,
            reason: 'stale_location',
            details:
                'source=driver_locations last_ping=${row['last_location_ping_at']} '
                'updated_at=${row['updated_at']}',
          ),
        );
        return null;
      }
      return AssignmentLocation(
        name: row['city']?.toString() ?? 'Driver $driverId',
        address: row['address_text']?.toString() ?? row['city']?.toString(),
        lat: lat,
        lng: lng,
      );
    } catch (_) {
      return null;
    }
  }

  AssignmentLocation _pickupLocation(
    Map<String, dynamic> order,
    Map<String, dynamic>? branch,
    Map<String, dynamic>? pickupPoint,
    Map<String, dynamic>? address,
  ) {
    final pickupSourceType = order['pickup_source_type']
        ?.toString()
        .trim()
        .toLowerCase();
    if (pickupSourceType == 'pickup_point' && pickupPoint != null) {
      return AssignmentLocation(
        name: pickupPoint['name']?.toString() ?? 'Pickup point',
        address: pickupPoint['address_text']?.toString(),
        lat: _toDouble(pickupPoint['lat']),
        lng: _toDouble(pickupPoint['lng']),
      );
    }

    final explicitPickupLat = _toDouble(order['pickup_location_lat']);
    final explicitPickupLng = _toDouble(order['pickup_location_lng']);
    if (explicitPickupLat != null && explicitPickupLng != null) {
      return AssignmentLocation(
        name: order['merchant_name']?.toString() ?? 'Merchant pickup',
        address:
            address?['pickup_address_text']?.toString() ??
            order['pickup_address_text']?.toString(),
        lat: explicitPickupLat,
        lng: explicitPickupLng,
      );
    }

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
      lat: _toDouble(
        order['pickup_location_lat'] ??
            address?['pickup_lat'] ??
            order['pickup_lat'],
      ),
      lng: _toDouble(
        order['pickup_location_lng'] ??
            address?['pickup_lng'] ??
            order['pickup_lng'],
      ),
    );
  }

  AssignmentLocation _dropoffLocation(
    Map<String, dynamic> order,
    Map<String, dynamic>? address,
    Map<String, dynamic>? pickupPoint,
    DropoffType dropoffType,
  ) {
    final status = order['status']?.toString().trim().toLowerCase() ?? '';
    final backupIsActive = dropoffType == DropoffType.home &&
        pickupPoint != null &&
        const {
          'pending_pickup_point_delivery',
          'dropped_at_pickup_point',
        }.contains(status);

    if ((dropoffType == DropoffType.pickupPoint || backupIsActive) &&
        pickupPoint != null) {
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
        order['customer_address_text'],
        order['dropoff_address_text'],
        address?['dropoff_address_text'],
        address?['dropoff_address'],
      ]),
      lat: _toDouble(
        order['dropoff_location_lat'] ??
            address?['dropoff_lat'] ??
            order['customer_lat'] ??
            order['dropoff_lat'],
      ),
      lng: _toDouble(
        order['dropoff_location_lng'] ??
            address?['dropoff_lng'] ??
            order['customer_lng'] ??
            order['dropoff_lng'],
      ),
    );
  }

  DropoffType _parseDropoffType(Map<String, dynamic> order) {
    final raw = order['dropoff_type']?.toString().toLowerCase();
    if (raw == 'home' || raw == 'home_delivery') {
      return DropoffType.home;
    }
    if (raw == 'pickup_point' ||
        raw == 'pickup point' ||
        raw == 'pickup_point_specific' ||
        raw == 'pickup_point_nearest') {
      return DropoffType.pickupPoint;
    }
    return order['destination_pickup_point_id'] == null
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
      final rawItemCount = _toInt(
        row['item_count'] ??
            row['items_count'] ??
            row['package_count'] ??
            row['quantity'],
      );
      final normalizedDemand = DeliveryConstraintDefaults.normalizeOrderDemand(
        // Keep auto-assignment resilient for legacy orders with missing count.
        itemCount: rawItemCount == null || rawItemCount <= 0 ? 1 : rawItemCount,
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

    final isAvailable = row['is_available'];
    if (isAvailable is bool && !isAvailable) return false;

    if (row['is_active_shift'] != true) return false;

    final status = row['availability_status']?.toString().toLowerCase();
    return status == 'available';
  }

  /// Dashboard "on shift + available" is ideal. For **auto-assign** we also
  /// allow approved drivers unless they explicitly opted out, then use last
  /// known coordinates for routing (see [allowStaleCoordinates] on
  /// [_loadFreshDriverLocation]).
  bool _isDriverAssignableForAutoAssign(Map<String, dynamic> row) {
    if (_isDriverAvailable(row)) return true;

    final status = row['availability_status']?.toString().trim().toLowerCase();
    const blocked = {'offline', 'on_break', 'paused', 'busy'};
    if (status != null && status.isNotEmpty && blocked.contains(status)) {
      return false;
    }
    return true;
  }

  bool _isFreshPing(DateTime? pingAt, {Duration? maxAge}) {
    if (pingAt == null) return false;
    final age = DateTime.now().toUtc().difference(pingAt.toUtc());
    return age <= (maxAge ?? _freshLocationWindow);
  }

  String _classifyAutoAssignDriverLoopError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('missing pickup') ||
        text.contains('missing package demand')) {
      return 'assignment_data_incomplete';
    }
    if (text.contains('route-estimate') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup')) {
      return 'routing_request_failed';
    }
    if (text.contains('timeout')) {
      return 'routing_timeout';
    }
    return 'routing_or_insertion_error';
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

  bool _isRouteInactiveStatus(String status) {
    final normalized = status.toLowerCase();
    return _isCompletedStatus(normalized) ||
        const {'failed', 'rescheduled'}.contains(normalized);
  }

  Future<bool> isDriverCurrentlyAvailable(String driverId) async {
    final row = await _db
        .from('drivers')
        .select('*')
        .eq('id', driverId)
        .limit(1)
        .maybeSingle();
    if (row == null) return false;
    return _isDriverAvailable(row);
  }

  Future<Map<String, dynamic>?> getDriverActiveOrder(String driverId) async {
    final rows = await _db
        .from('assignments')
        .select('order_id, assigned_at')
        .eq('driver_id', driverId)
        .isFilter('completed_at', null)
        .limit(20);
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final orderId = row['order_id']?.toString();
      if (orderId == null || orderId.isEmpty) continue;
      final active = await _loadActiveAssignmentContext(
        orderId: orderId,
        expectedDriverId: driverId,
      );
      if (active == null) continue;
      return {'order_id': orderId, 'status': active.$1};
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDriverActiveOrderForCompany({
    required String driverId,
    required String companyId,
  }) async {
    final rows = await _db
        .from('assignments')
        .select('order_id, assigned_at')
        .eq('driver_id', driverId)
        .eq('company_id', companyId)
        .isFilter('completed_at', null)
        .limit(20);
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final orderId = row['order_id']?.toString();
      if (orderId == null || orderId.isEmpty) continue;
      final active = await _loadActiveAssignmentContext(
        orderId: orderId,
        expectedDriverId: driverId,
      );
      if (active == null) continue;
      final orderCompanyId = active.$3;
      if (orderCompanyId != null &&
          orderCompanyId.isNotEmpty &&
          orderCompanyId != companyId) {
        continue;
      }
      return {'order_id': orderId, 'status': active.$1};
    }
    return null;
  }

  /// Returns active assignment context only when the order is still linked to
  /// the same driver. This ignores stale/orphan assignment rows left behind
  /// after unassign/retry flows.
  Future<(String, String?, String?)?> _loadActiveAssignmentContext({
    required String orderId,
    required String expectedDriverId,
  }) async {
    final row = await _db
        .from('orders')
        .select('status, assigned_driver_id, delivery_company_id, company_id')
        .eq('id', orderId)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;

    final status = row['status']?.toString().trim().toLowerCase();
    if (status == null || status.isEmpty) return null;
    if (_isRouteInactiveStatus(status)) return null;
    // "On a delivery" should mean physically active delivery work, not just
    // pre-accept / awaiting-response assignments.
    if (!_isLoadedStatus(status)) return null;

    final assignedDriverId = row['assigned_driver_id']?.toString().trim();
    if (assignedDriverId == null ||
        assignedDriverId.isEmpty ||
        assignedDriverId != expectedDriverId) {
      return null;
    }

    final companyId = _firstNonEmpty([
      row['delivery_company_id'],
      row['company_id'],
    ]);
    return (status, assignedDriverId, companyId);
  }

  Future<void> releaseDriverAfterOrderFinished({
    required String orderId,
    required String driverId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _db
          .from('assignments')
          .update({'completed_at': now})
          .eq('order_id', orderId)
          .eq('driver_id', driverId);
    } catch (_) {}
    try {
      await _db
          .from('driver_route_stops')
          .update({'completed_at': now, 'updated_at': now})
          .eq('order_id', orderId)
          .eq('driver_id', driverId)
          .isFilter('completed_at', null);
    } catch (_) {}
  }

  Future<AssignmentLocation?> getFreshDriverLocation(String driverId) async {
    final row = await _db
        .from('drivers')
        .select('*')
        .eq('id', driverId)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _loadFreshDriverLocation(driverId, row);
  }

  String explainDriverRejection({
    required String driverId,
    required String reason,
    String? details,
  }) {
    final suffix = details == null || details.trim().isEmpty ? '' : ' | $details';
    return '[auto-assign] reject driver=$driverId reason=$reason$suffix';
  }

  void _debug(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
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
