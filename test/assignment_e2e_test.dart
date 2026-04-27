import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/features/orders/data/assignment_models.dart';
import 'package:wasle/features/orders/data/order_assignment_service.dart';
import 'package:wasle/features/orders/data/routing_service.dart';

const _supabaseUrl = 'https://sjeryiftpcfkjwepsldz.supabase.co';

class _Ids {
  static const companyA = '11111111-1111-4111-8111-111111111111';
  static const companyB = '22222222-2222-4222-8222-222222222222';
  static const merchant = '33333333-3333-4333-8333-333333333333';
  static const branch = '44444444-4444-4444-8444-444444444444';
  static const merchantCompanyMap = '99999999-1111-4111-8111-111111111111';

  static const driverA1 = '55555555-5555-4555-8555-555555555555';
  static const driverA2 = '66666666-6666-4666-8666-666666666666';
  static const driverA3 = '77777777-7777-4777-8777-777777777777';
  static const driverB1 = '88888888-8888-4888-8888-888888888888';

  static const busyOrder = '99999999-9999-4999-8999-999999999999';
  static const smallOrder = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  static const mediumOrder = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
  static const largeOrder = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3';
  static const oversizedOrder = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd4';

  static const busyAddress = 'aaaaaaaa-0000-4aaa-8aaa-aaaaaaaaaaaa';
  static const smallAddress = 'bbbbbbbb-0000-4bbb-8bbb-bbbbbbbbbbbb';
  static const mediumAddress = 'cccccccc-0000-4ccc-8ccc-cccccccccccc';
  static const largeAddress = 'dddddddd-0000-4ddd-8ddd-dddddddddddd';
  static const oversizedAddress = 'eeeeeeee-0000-4eee-8eee-eeeeeeeeeeee';

  static const busyAssignment = 'ffffffff-0000-4fff-8fff-ffffffffffff';
}

class _LiveRouteEstimateService implements RoutingService {
  _LiveRouteEstimateService({
    required this.supabaseUrl,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String supabaseUrl;
  final String apiKey;
  final http.Client _client;
  final List<Map<String, dynamic>> callLog = [];

  @override
  Future<TravelEstimate> getTravelEstimate({
    required AssignmentLocation origin,
    required AssignmentLocation destination,
    DateTime? departureTime,
    String? vehicleType,
  }) async {
    final originLat = origin.lat;
    final originLng = origin.lng;
    final destinationLat = destination.lat;
    final destinationLng = destination.lng;
    if ([originLat, originLng, destinationLat, destinationLng].contains(null)) {
      throw StateError('Missing coordinates for route-estimate test call.');
    }

    final uri = Uri.parse('$supabaseUrl/functions/v1/route-estimate');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'origin': {'lat': originLat, 'lng': originLng},
        'destination': {'lat': destinationLat, 'lng': destinationLng},
        'vehicleType': vehicleType ?? 'motorcycle',
      }),
    );

    if (response.statusCode != 200) {
      throw StateError(
        'route-estimate failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final estimate = TravelEstimate(
      durationSeconds: (data['durationSeconds'] as num).round(),
      distanceMeters: (data['distanceMeters'] as num).toDouble(),
      source: data['source']?.toString() ?? 'unknown',
    );
    callLog.add({
      'origin': {'lat': originLat, 'lng': originLng},
      'destination': {'lat': destinationLat, 'lng': destinationLng},
      'vehicleType': vehicleType ?? 'motorcycle',
      'source': estimate.source,
      'durationSeconds': estimate.durationSeconds,
      'distanceMeters': estimate.distanceMeters,
    });
    return estimate;
  }
}

String _serviceRoleKey() {
  final key = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (key == null || key.isEmpty) {
    throw StateError('SUPABASE_SERVICE_ROLE_KEY is required for e2e test.');
  }
  return key;
}

Future<void> _cleanup(SupabaseClient db) async {
  final orderIds = [
    _Ids.busyOrder,
    _Ids.smallOrder,
    _Ids.mediumOrder,
    _Ids.largeOrder,
    _Ids.oversizedOrder,
  ];
  final driverIds = [
    _Ids.driverA1,
    _Ids.driverA2,
    _Ids.driverA3,
    _Ids.driverB1,
  ];

  await db.from('driver_route_stops').delete().inFilter('order_id', orderIds);
  await db.from('driver_routes').delete().inFilter('driver_id', driverIds);
  await db.from('assignments').delete().inFilter('order_id', orderIds);
  await db.from('order_events').delete().inFilter('order_id', orderIds);
  await db.from('order_addresses').delete().inFilter('order_id', orderIds);
  await db.from('orders').delete().inFilter('id', orderIds);
  await db.from('driver_locations').delete().inFilter('driver_id', driverIds);
}

Future<void> _seed(SupabaseClient db) async {
  final now = DateTime.now().toUtc().toIso8601String();

  await db.from('delivery_companies').upsert([
    {
      'id': _Ids.companyA,
      'name': 'E2E Company A',
      'verification_status': 'approved',
      'location': 'Beirut',
    },
    {
      'id': _Ids.companyB,
      'name': 'E2E Company B',
      'verification_status': 'approved',
      'location': 'Beirut',
    },
  ], onConflict: 'id');

  await db.from('merchant_businesses').upsert({
    'id': _Ids.merchant,
    'name': 'E2E Merchant',
    'is_active': true,
  }, onConflict: 'id');

  await db.from('merchant_branches').upsert({
    'id': _Ids.branch,
    'merchant_id': _Ids.merchant,
    'name': 'E2E Main Branch',
    'address_text': 'Hamra, Beirut',
    'lat': 33.8938,
    'lng': 35.5018,
    'is_active': true,
  }, onConflict: 'id');

  await db.from('merchant_delivery_companies').upsert({
    'id': _Ids.merchantCompanyMap,
    'merchant_id': _Ids.merchant,
    'company_id': _Ids.companyA,
    'is_active': true,
  }, onConflict: 'merchant_id,company_id');

  await db.from('drivers').upsert([
    {
      'id': _Ids.driverA1,
      'company_id': _Ids.companyA,
      'verification_status': 'approved',
      'vehicle_type': 'motorcycle',
      'capacity_weight': 15,
      'capacity_volume': 40000,
      'capacity_item_count': 5,
      'availability_status': 'available',
      'is_available': true,
      'is_active_shift': true,
      'shift_started_at': now,
      'last_location_ping_at': now,
      'current_location_lat': 33.8942,
      'current_location_lng': 35.5030,
    },
    {
      'id': _Ids.driverA2,
      'company_id': _Ids.companyA,
      'verification_status': 'approved',
      'vehicle_type': 'car',
      'capacity_weight': 60,
      'capacity_volume': 200000,
      'capacity_item_count': 20,
      'availability_status': 'available',
      'is_available': true,
      'is_active_shift': true,
      'shift_started_at': now,
      'last_location_ping_at': now,
      'current_location_lat': 33.8900,
      'current_location_lng': 35.4920,
    },
    {
      'id': _Ids.driverA3,
      'company_id': _Ids.companyA,
      'verification_status': 'approved',
      'vehicle_type': 'van',
      'capacity_weight': 300,
      'capacity_volume': 1000000,
      'capacity_item_count': 80,
      'availability_status': 'available',
      'is_available': true,
      'is_active_shift': true,
      'shift_started_at': now,
      'last_location_ping_at': now,
      'current_location_lat': 33.8995,
      'current_location_lng': 35.4880,
    },
    {
      'id': _Ids.driverB1,
      'company_id': _Ids.companyB,
      'verification_status': 'approved',
      'vehicle_type': 'car',
      'capacity_weight': 60,
      'capacity_volume': 200000,
      'capacity_item_count': 20,
      'availability_status': 'available',
      'is_available': true,
      'is_active_shift': true,
      'shift_started_at': now,
      'last_location_ping_at': now,
      'current_location_lat': 33.8939,
      'current_location_lng': 35.5019,
    },
  ], onConflict: 'id');

  await db.from('driver_locations').upsert([
    {
      'driver_id': _Ids.driverA1,
      'lat': 33.8942,
      'lng': 35.5030,
      'city': 'Beirut',
      'last_location_ping_at': now,
      'updated_at': now,
    },
    {
      'driver_id': _Ids.driverA2,
      'lat': 33.8900,
      'lng': 35.4920,
      'city': 'Beirut',
      'last_location_ping_at': now,
      'updated_at': now,
    },
    {
      'driver_id': _Ids.driverA3,
      'lat': 33.8995,
      'lng': 35.4880,
      'city': 'Beirut',
      'last_location_ping_at': now,
      'updated_at': now,
    },
    {
      'driver_id': _Ids.driverB1,
      'lat': 33.8939,
      'lng': 35.5019,
      'city': 'Beirut',
      'last_location_ping_at': now,
      'updated_at': now,
    },
  ], onConflict: 'driver_id');

  await db.from('orders').upsert([
    _orderRow(
      id: _Ids.busyOrder,
      trackingCode: 'E2E-BUSY',
      weight: 2,
      volume: 10000,
      items: 1,
      customerName: 'Busy Customer',
      customerPhone: '+96170000001',
      customerAddress: 'Ashrafieh East',
      dropoffLat: 33.9140,
      dropoffLng: 35.5300,
    )..['status'] = 'assigned',
    _orderRow(
      id: _Ids.smallOrder,
      trackingCode: 'E2E-SMALL',
      weight: 2,
      volume: 5000,
      items: 1,
      customerName: 'Small Customer',
      customerPhone: '+96170000002',
      customerAddress: 'Verdun West',
      dropoffLat: 33.8890,
      dropoffLng: 35.4915,
    ),
    _orderRow(
      id: _Ids.mediumOrder,
      trackingCode: 'E2E-MEDIUM',
      weight: 25,
      volume: 90000,
      items: 8,
      customerName: 'Medium Customer',
      customerPhone: '+96170000003',
      customerAddress: 'Mazraa',
      dropoffLat: 33.8875,
      dropoffLng: 35.4895,
    ),
    _orderRow(
      id: _Ids.largeOrder,
      trackingCode: 'E2E-LARGE',
      weight: 120,
      volume: 400000,
      items: 30,
      customerName: 'Large Customer',
      customerPhone: '+96170000004',
      customerAddress: 'Jnah',
      dropoffLat: 33.9005,
      dropoffLng: 35.4905,
    ),
    _orderRow(
      id: _Ids.oversizedOrder,
      trackingCode: 'E2E-OVERSIZED',
      weight: 400,
      volume: 1500000,
      items: 120,
      customerName: 'Oversized Customer',
      customerPhone: '+96170000005',
      customerAddress: 'Downtown',
      dropoffLat: 33.8920,
      dropoffLng: 35.4990,
    ),
  ], onConflict: 'id');

  await db.from('order_addresses').upsert([
    _addressRow(
      id: _Ids.busyAddress,
      orderId: _Ids.busyOrder,
      dropoffLat: 33.9140,
      dropoffLng: 35.5300,
      dropoffText: 'Ashrafieh East',
    ),
    _addressRow(
      id: _Ids.smallAddress,
      orderId: _Ids.smallOrder,
      dropoffLat: 33.8890,
      dropoffLng: 35.4915,
      dropoffText: 'Verdun West',
    ),
    _addressRow(
      id: _Ids.mediumAddress,
      orderId: _Ids.mediumOrder,
      dropoffLat: 33.8875,
      dropoffLng: 35.4895,
      dropoffText: 'Mazraa',
    ),
    _addressRow(
      id: _Ids.largeAddress,
      orderId: _Ids.largeOrder,
      dropoffLat: 33.9005,
      dropoffLng: 35.4905,
      dropoffText: 'Jnah',
    ),
    _addressRow(
      id: _Ids.oversizedAddress,
      orderId: _Ids.oversizedOrder,
      dropoffLat: 33.8920,
      dropoffLng: 35.4990,
      dropoffText: 'Downtown',
    ),
  ], onConflict: 'id');

  await db.from('assignments').upsert({
    'id': _Ids.busyAssignment,
    'order_id': _Ids.busyOrder,
    'company_id': _Ids.companyA,
    'driver_id': _Ids.driverA1,
    'assigned_at': DateTime.now().toUtc().toIso8601String(),
    'status': 'assigned',
  }, onConflict: 'order_id');
}

Map<String, dynamic> _orderRow({
  required String id,
  required String trackingCode,
  required double weight,
  required double volume,
  required int items,
  required String customerName,
  required String customerPhone,
  required String customerAddress,
  required double dropoffLat,
  required double dropoffLng,
}) {
  return {
    'id': id,
    'merchant_id': _Ids.merchant,
    'branch_id': _Ids.branch,
    'tracking_code': trackingCode,
    'status': 'created',
    'delivery_company_id': _Ids.companyA,
    'dropoff_type': 'home',
    'item_count': items,
    'estimated_weight': weight,
    'estimated_volume': volume,
    'priority': 0,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'customer_address_text': customerAddress,
    'customer_lat': dropoffLat,
    'customer_lng': dropoffLng,
    'parcel_description': 'E2E parcel',
    'declared_value': 50,
    'notes': 'E2E assignment test',
  };
}

Map<String, dynamic> _addressRow({
  required String id,
  required String orderId,
  required double dropoffLat,
  required double dropoffLng,
  required String dropoffText,
}) {
  return {
    'id': id,
    'order_id': orderId,
    'pickup_address_text': 'Hamra, Beirut',
    'pickup_lat': 33.8938,
    'pickup_lng': 35.5018,
    'dropoff_address_text': dropoffText,
    'dropoff_lat': dropoffLat,
    'dropoff_lng': dropoffLng,
  };
}

Future<Map<String, dynamic>> _fetchOrderArtifacts(
  SupabaseClient db,
  String orderId,
) async {
  final assignment = await db
      .from('assignments')
      .select('*')
      .eq('order_id', orderId)
      .maybeSingle();
  final events = await db
      .from('order_events')
      .select('event_type, note, metadata, created_at')
      .eq('order_id', orderId)
      .order('created_at');

  if (assignment == null) {
    return {'assignment': null, 'route': null, 'stops': [], 'events': events};
  }

  final driverId = assignment['driver_id']?.toString();
  final route = driverId == null
      ? null
      : await db
            .from('driver_routes')
            .select('*')
            .eq('driver_id', driverId)
            .eq('status', 'active')
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();
  final routeId = route?['id']?.toString();
  final stops = routeId == null
      ? <dynamic>[]
      : await db
            .from('driver_route_stops')
            .select('*')
            .eq('route_id', routeId)
            .order('sequence_index');

  return {
    'assignment': assignment,
    'route': route,
    'stops': stops,
    'events': events,
  };
}

void main() {
  test(
    'runs end-to-end automated assignment scenarios',
    () async {
      final serviceRoleKey = _serviceRoleKey();
      final db = SupabaseClient(_supabaseUrl, serviceRoleKey);
      final routingService = _LiveRouteEstimateService(
        supabaseUrl: _supabaseUrl,
        apiKey: serviceRoleKey,
      );
      final assignmentService = OrderAssignmentService(
        client: db,
        routingService: routingService,
      );

      await _cleanup(db);
      await _seed(db);

      final results = <Map<String, dynamic>>[];
      final driverLabels = {
        _Ids.driverA1: 'A1 motorcycle',
        _Ids.driverA2: 'A2 car',
        _Ids.driverA3: 'A3 van',
        _Ids.driverB1: 'B1 car (other company)',
      };

      for (final scenario in [
        {'name': 'small', 'orderId': _Ids.smallOrder},
        {'name': 'medium', 'orderId': _Ids.mediumOrder},
        {'name': 'large', 'orderId': _Ids.largeOrder},
        {'name': 'oversized', 'orderId': _Ids.oversizedOrder},
      ]) {
        final before = routingService.callLog.length;
        final result = await assignmentService.autoAssignOrder(
          scenario['orderId']!,
          merchantIdHint: _Ids.merchant,
        );
        final artifacts = await _fetchOrderArtifacts(db, scenario['orderId']!);
        final routeCalls = routingService.callLog.sublist(before);
        final selectedDriverId =
            (artifacts['assignment'] as Map<String, dynamic>?)?['driver_id']
                ?.toString();

        results.add({
          'scenario': scenario['name'],
          'orderId': scenario['orderId'],
          'assigned': result.assigned,
          'reason': result.reason,
          'selectedDriverId': selectedDriverId,
          'selectedDriverLabel': driverLabels[selectedDriverId],
          'costSeconds': result.costSeconds,
          'testedDrivers': result.testedDrivers,
          'feasibleInsertions': result.feasibleInsertions,
          'routingSources': routeCalls
              .map((call) => call['source'])
              .toSet()
              .toList(),
          'routeCallCount': routeCalls.length,
          'assignment': artifacts['assignment'],
          'route': artifacts['route'],
          'stopCount': (artifacts['stops'] as List).length,
          'stops': artifacts['stops'],
          'events': artifacts['events'],
        });
      }

      final cacheRows = await db.from('routing_cache').select('id');

      final summary = {
        'results': results,
        'routingCacheRowCount': (cacheRows as List).length,
        'routeEstimateCallLog': routingService.callLog,
      };

      debugPrint('E2E_ASSIGNMENT_RESULTS:${jsonEncode(summary)}');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
