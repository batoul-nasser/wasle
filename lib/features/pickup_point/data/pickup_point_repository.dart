import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PickupPointRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getMyPickupPoint() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    // Check pickup_point_operators first (signup flow writes here)
    final link = await _client
        .from('pickup_point_operators')
        .select('pickup_point_id')
        .eq('profile_id', user.id)
        .maybeSingle();

    if (link != null) {
      final ppId = link['pickup_point_id'].toString();
      final row = await _client
          .from('pickup_points')
          .select(
            'id, name, owner_name, address_text, phone, email, city, area, '
            'image_url, opens_at, closes_at, opening_hours, preferred_payment_method, '
            'payment_handling_method, working_days, max_orders_per_day, status, is_active',
          )
          .eq('id', ppId)
          .maybeSingle();
      return row;
    }

    // Fallback: check owner_profile_id
    final row = await _client
        .from('pickup_points')
        .select(
          'id, name, owner_name, address_text, phone, email, city, area, '
          'image_url, opens_at, closes_at, opening_hours, preferred_payment_method, '
          'payment_handling_method, working_days, max_orders_per_day, status, is_active',
        )
        .eq('owner_profile_id', user.id)
        .maybeSingle();
    return row;
  }

  Future<List<Map<String, dynamic>>> getPickupPointsForSearch() async {
    final rows = await _client
        .from('pickup_points')
        .select(
          'id, name, owner_name, address_text, city, area, phone, image_url, '
          'opening_hours, working_days, max_orders_per_day, '
          'preferred_payment_method, payment_handling_method, status',
        )
        .eq('is_active', true)
        .order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, int>> getPickupPointUsageCounts(
    List<String> pickupPointIds,
  ) async {
    if (pickupPointIds.isEmpty) return {};

    final rows = await _client
        .from('orders')
        .select('pickup_point_id, destination_pickup_point_id')
        .or(
          'pickup_point_id.in.(${pickupPointIds.join(",")}),'
          'destination_pickup_point_id.in.(${pickupPointIds.join(",")})',
        );

    final counts = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final sourceId = row['pickup_point_id']?.toString();
      final destinationId = row['destination_pickup_point_id']?.toString();
      if (sourceId != null && sourceId.isNotEmpty) {
        counts[sourceId] = (counts[sourceId] ?? 0) + 1;
      }
      if (destinationId != null && destinationId.isNotEmpty) {
        counts[destinationId] = (counts[destinationId] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<String?> uploadShopImage({
    required String pickupPointId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path =
        'shops/$pickupPointId-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _client.storage
        .from('pickup-point-shops')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('pickup-point-shops').getPublicUrl(path);
  }

  Future<void> updatePickupPointImage({
    required String pickupPointId,
    required String imageUrl,
  }) async {
    await _client
        .from('pickup_points')
        .update({'image_url': imageUrl})
        .eq('id', pickupPointId);
  }

  Future<List<Map<String, dynamic>>> getPickupPointParcels({
    required String pickupPointId,
  }) async {
    final orderRows = await _client
        .from('orders')
        .select(
          'id, tracking_code, status, assignment_status, '
          'delivery_company_id, company_id, assigned_driver_id, '
          'created_at, updated_at, customer_profile_id, '
          'pickup_point_id, destination_pickup_point_id, dropoff_type, '
          'customer_name, customer_phone, merchant_id, '
          'pickup_location_lat, pickup_location_lng, '
          'dropoff_location_lat, dropoff_location_lng, customer_address_text',
        )
        .or(
          'pickup_point_id.eq.$pickupPointId,'
          'destination_pickup_point_id.eq.$pickupPointId',
        )
        .order('created_at', ascending: false);

    final orders = List<Map<String, dynamic>>.from(orderRows);
    if (orders.isEmpty) return [];

    final customerIds = orders
        .map((order) => order['customer_profile_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final customers = customerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('profiles')
                .select('id, full_name, phone')
                .inFilter('id', customerIds),
          );

    final orderIds = orders
        .map((order) => order['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    final paymentRows = orderIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('payments')
                .select('order_id, method, status, amount')
                .inFilter('order_id', orderIds),
          );
    final paymentByOrderId = <String, Map<String, dynamic>>{
      for (final row in paymentRows)
        if (row['order_id'] != null) row['order_id'].toString(): row,
    };
    final assignmentRows = orderIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('assignments')
                .select('order_id, driver_id, assigned_at')
                .inFilter('order_id', orderIds)
                .order('assigned_at', ascending: false),
          );
    final assignmentByOrderId = <String, Map<String, dynamic>>{};
    for (final row in assignmentRows) {
      final orderId = row['order_id']?.toString();
      if (orderId == null || orderId.isEmpty) continue;
      assignmentByOrderId.putIfAbsent(orderId, () => row);
    }

    final companyIds = <String>{
      ...orders
          .map((o) => o['delivery_company_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
      ...orders
          .map((o) => o['company_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
    }.toList();
    final companyRows = companyIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('delivery_companies')
                .select('id, name, phone')
                .inFilter('id', companyIds),
          );
    final companyById = <String, Map<String, dynamic>>{
      for (final row in companyRows)
        if (row['id'] != null) row['id'].toString(): row,
    };

    final driverIds = <String>{
      ...orders
          .map((o) => o['assigned_driver_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
      ...assignmentRows
          .map((a) => a['driver_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
    }.toList();
    final driverRows = driverIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('drivers')
                .select(
                  'id, profile_id, vehicle_type, availability_status, verification_status',
                )
                .inFilter('id', driverIds),
          );
    final driverById = <String, Map<String, dynamic>>{
      for (final row in driverRows)
        if (row['id'] != null) row['id'].toString(): row,
    };
    final profileIds = driverRows
        .map((d) => d['profile_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final profileRows = profileIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('profiles')
                .select('id, full_name, phone, role, created_at, updated_at')
                .inFilter('id', profileIds),
          );
    final profileById = <String, Map<String, dynamic>>{
      for (final row in profileRows)
        if (row['id'] != null) row['id'].toString(): row,
    };

    final pickupIds = <String>{
      ...orders
          .map((order) => order['pickup_point_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
      ...orders
          .map((order) => order['destination_pickup_point_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
    }.toList();
    final pickupRows = pickupIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('pickup_points')
                .select(
                  'id, name, address_text, lat, lng, city, area, preferred_payment_method, payment_handling_method',
                )
                .inFilter('id', pickupIds),
          );
    final pickupById = <String, Map<String, dynamic>>{
      for (final row in pickupRows)
        if (row['id'] != null) row['id'].toString(): row,
    };

    final customerById = {
      for (final customer in customers)
        if (customer['id'] != null) customer['id'].toString(): customer,
    };

    final visibleOrders = orders.where((order) {
      final dropoffType = order['dropoff_type']?.toString().trim().toLowerCase() ?? '';
      final status = order['status']?.toString().trim().toLowerCase() ?? '';
      final destinationId = order['destination_pickup_point_id']?.toString();
      final isBackupForCurrentPickup =
          destinationId == pickupPointId && dropoffType == 'home';
      if (!isBackupForCurrentPickup) return true;
      return status == 'pending_pickup_point_delivery' ||
          status == 'dropped_at_pickup_point';
    }).toList();

    return visibleOrders.map((order) {
      final customer =
          customerById[order['customer_profile_id']?.toString()] ?? {};
      final status = order['status']?.toString().trim().toLowerCase() ?? '';
      final dropoffType = order['dropoff_type']?.toString().trim().toLowerCase() ?? '';
      final sourceId = order['pickup_point_id']?.toString();
      final destinationId = order['destination_pickup_point_id']?.toString();
      final payment = paymentByOrderId[order['id']?.toString() ?? ''];
      final assignment = assignmentByOrderId[order['id']?.toString() ?? ''];
      final deliveryCompanyId = (order['delivery_company_id']?.toString().trim().isNotEmpty ?? false)
          ? order['delivery_company_id']?.toString()
          : order['company_id']?.toString();
      final company = deliveryCompanyId == null ? null : companyById[deliveryCompanyId];
      final assignedDriverId =
          order['assigned_driver_id']?.toString() ?? assignment?['driver_id']?.toString();
      final assignmentDriverId = assignment?['driver_id']?.toString();
      final driver = assignedDriverId == null ? null : driverById[assignedDriverId];
      final driverProfile = driver == null
          ? null
          : profileById[driver['profile_id']?.toString()];
      final sourcePickup = pickupById[sourceId];
      final destinationPickup = pickupById[destinationId];
      final currentPickup = pickupById[pickupPointId];
      final role = destinationId == pickupPointId
          ? (dropoffType == 'home'
                ? 'backup_option_2'
                : 'destination_pickup')
          : 'source_pickup';
      final paymentEligibleStatuses = const <String>{
        'pending_pickup_point_delivery',
        'dropped_at_pickup_point',
        'ready_for_customer_pickup',
      };
      final paymentMethod = payment?['method']?.toString().trim().toLowerCase() ?? '';
      final paymentStatus = payment?['status']?.toString().trim().toLowerCase() ?? '';
      final isSourcePickup = role == 'source_pickup';
      final isDestinationPickup = destinationId == pickupPointId;
      final isSpecificDestination =
          isDestinationPickup && dropoffType == 'pickup_point_specific';
      final isActiveBackup = isDestinationPickup &&
          dropoffType == 'home' &&
          paymentEligibleStatuses.contains(status);
      final isOnline = paymentMethod == 'whish_online';
      final isCashAtPickup = paymentMethod == 'cash_at_pickup';
      final canCollectPayment = !isSourcePickup &&
          isDestinationPickup &&
          isCashAtPickup &&
          paymentStatus == 'pending' &&
          (isSpecificDestination || isActiveBackup);
      final pickupHandling = _normalizePickupHandling({
        'preferred_payment_method': currentPickup?['preferred_payment_method'],
        'payment_handling_method': currentPickup?['payment_handling_method'],
      });

      String paymentCollectionLabel;
      if (isOnline) {
        paymentCollectionLabel = 'Online payment — no pickup collection';
      } else if (isSourcePickup) {
        paymentCollectionLabel = 'No payment collection';
      } else if (canCollectPayment) {
        if (pickupHandling == 'agent_collection') {
          paymentCollectionLabel = 'Agent collection required';
        } else {
          paymentCollectionLabel = 'Payment eligible here';
        }
      } else {
        paymentCollectionLabel = 'No payment collection';
      }

      final readableStatus = _statusLabel(order['status']?.toString());
      final readableAssignment = _statusLabel(order['assignment_status']?.toString());
      final hasDriver = driver != null && driverProfile != null;
      final statusNotAssignedYet = {
        'created',
        'pending',
        'assigned',
        'pending_driver_receipt',
      }.contains(status);
      final companyName = company?['name']?.toString();
      final deliveryCompanyName = (companyName != null && companyName.trim().isNotEmpty)
          ? companyName
          : (statusNotAssignedYet ? 'Not assigned yet' : 'No company assigned');
      final driverName = hasDriver
          ? (driverProfile['full_name']?.toString() ?? 'No driver assigned')
          : (statusNotAssignedYet ? 'Not assigned yet' : 'No driver assigned');
      final driverPhone = hasDriver
          ? (driverProfile['phone']?.toString() ?? '-')
          : '-';
      final vehicleType = hasDriver
          ? (driver['vehicle_type']?.toString() ?? 'Unknown vehicle')
          : (statusNotAssignedYet ? 'Not assigned yet' : 'Unknown vehicle');

      final mapped = {
        'order_id': order['id']?.toString(),
        'tracking_code': order['tracking_code']?.toString() ?? order['id']?.toString(),
        'status': order['status']?.toString(),
        'assignment_status': order['assignment_status']?.toString(),
        'delivery_company_id': order['delivery_company_id']?.toString(),
        'company_id': order['company_id']?.toString(),
        'assigned_driver_id': order['assigned_driver_id']?.toString(),
        'dropoff_type': dropoffType,
        'pickup_point_id': sourceId,
        'destination_pickup_point_id': destinationId,
        'is_destination_pickup': destinationId == pickupPointId,
        'pickup_role': role,
        'pickup_role_label': role == 'source_pickup'
            ? 'Source Pickup'
            : (role == 'destination_pickup'
                  ? 'Destination Pickup'
                  : 'Backup Pickup Point / Option 2'),
        'payment_can_collect_here': canCollectPayment,
        'payment_collection_label': paymentCollectionLabel,
        'payment_status': payment?['status']?.toString(),
        'payment_method': payment?['method']?.toString(),
        'payment_amount': payment?['amount'],
        'source_pickup_name': sourcePickup?['name']?.toString(),
        'source_pickup_address': sourcePickup?['address_text']?.toString(),
        'destination_pickup_name': destinationPickup?['name']?.toString(),
        'destination_pickup_address':
            destinationPickup?['address_text']?.toString(),
        'destination_pickup_lat': destinationPickup?['lat'],
        'destination_pickup_lng': destinationPickup?['lng'],
        'customer_address_text': order['customer_address_text'],
        'dropoff_location_lat': order['dropoff_location_lat'],
        'dropoff_location_lng': order['dropoff_location_lng'],
        'customer_name':
            customer['full_name']?.toString() ??
            order['customer_name']?.toString() ??
            'Customer',
        'customer_phone':
            customer['phone']?.toString() ??
            order['customer_phone']?.toString() ??
            '-',
        'delivery_company_name': deliveryCompanyName,
        'delivery_driver_name': driverName,
        'delivery_driver_phone': driverPhone,
        'delivery_vehicle_type': vehicleType,
        'delivery_status': readableStatus != 'Not available'
            ? readableStatus
            : readableAssignment,
        'delivery_assigned_at': assignment?['assigned_at'],
      };
      debugPrint(
        '[PICKUP_POINT_CARD] tracking=${mapped['tracking_code']} role=${mapped['pickup_role_label']} '
        'status=${mapped['status']} pickup_point_id=$sourceId destination_pickup_point_id=$destinationId',
      );
      debugPrint(
        '[PICKUP_POINT_COMPANY] deliveryCompanyId=${order['delivery_company_id']} companyId=${order['company_id']} companyName=$deliveryCompanyName',
      );
      debugPrint(
        '[PICKUP_POINT_DRIVER] assignedDriverId=$assignedDriverId assignmentDriverId=$assignmentDriverId '
        'driverName=$driverName driverPhone=$driverPhone vehicle=$vehicleType',
      );
      debugPrint(
        '[PICKUP_PAYMENT_ROLE] tracking=${mapped['tracking_code']} role=${mapped['pickup_role_label']} '
        'pickup_point_id=$sourceId destination_pickup_point_id=$destinationId '
        'dropoff_type=$dropoffType status=$status method=$paymentMethod paymentStatus=$paymentStatus '
        'handling=$pickupHandling canCollect=$canCollectPayment',
      );
      return mapped;
    }).toList();
  }

  String _normalizePickupHandling(Map<String, dynamic>? pickupPoint) {
    final preferred =
        pickupPoint?['preferred_payment_method']?.toString().trim().toLowerCase();
    final handling =
        pickupPoint?['payment_handling_method']?.toString().trim().toLowerCase();

    if (preferred == 'wish_money' || handling == 'wish_money') {
      return 'whish_wallet';
    }
    if (preferred == 'agent_collection' || handling == 'agent_collection') {
      return 'agent_collection';
    }
    if (preferred == 'customer_pays_at_pickup' ||
        handling == 'customer_pays_at_pickup') {
      return 'customer_pays_at_pickup';
    }
    return 'not_configured';
  }

  String _statusLabel(String? rawStatus) {
    final status = (rawStatus ?? '').trim().toLowerCase();
    switch (status) {
      case 'created':
        return 'Created';
      case 'assigned':
        return 'Assigned';
      case 'pending_driver_receipt':
        return 'Pending Driver Receipt';
      case 'driver_received_order':
        return 'Driver Accepted Order';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
      case 'pending_pickup_point_delivery':
        return 'Moving To Backup Pickup Point';
      case 'dropped_at_pickup_point':
        return 'Dropped At Pickup Point';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        if (status.isEmpty) return 'Not available';
        return status
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (part) =>
                  part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
            )
            .join(' ');
    }
  }

  Future<void> updateParcelStatus({
    required String orderId,
    required String newStatus,
  }) async {
    await _client
        .from('orders')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId);
  }

  Future<String?> uploadIssuePhoto({
    required String orderId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path =
        'issues/$orderId-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _client.storage
        .from('pickup-point-storage')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('pickup-point-storage').getPublicUrl(path);
  }

  Future<void> reportParcelIssue({
    required String orderId,
    required String pickupPointId,
    required String issueType,
    required String description,
    String? photoUrl,
  }) async {
    await _client.from('order_events').insert({
      'order_id': orderId,
      'event_type': 'pickup_point_issue',
      'note': description.isEmpty ? issueType : '$issueType: $description',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    if (photoUrl != null && photoUrl.isNotEmpty) {
      await _client.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'pickup_point_issue_photo',
        'note': photoUrl,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Stream<List<Map<String, dynamic>>> watchPickupPointOrders(
    String pickupPointId,
  ) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .map((rows) => List<Map<String, dynamic>>.from(rows).where((row) {
              final source = row['pickup_point_id']?.toString();
              final destination = row['destination_pickup_point_id']?.toString();
              return source == pickupPointId || destination == pickupPointId;
            }).toList())
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }
}
