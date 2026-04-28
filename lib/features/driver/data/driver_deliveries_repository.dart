import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/delivery_timeline_event.dart';
import 'models/driver_delivery.dart';
import 'models/driver_order_details.dart';

enum DeliveryBucket { active, completed }

class DriverDeliveriesRepository {
  final SupabaseClient _client = Supabase.instance.client;

  static const List<String> orderStatuses = [
    'created',
    'ready_for_driver_pickup',
    'assigned',
    'pending_driver_receipt',
    'driver_received_order',
    'picked_up',
    'in_transit',
    'delivered',
    'failed',
    'rescheduled',
    'pending_pickup_point_delivery',
    'dropped_at_pickup_point',
    'returning_to_store',
    'returned_to_store',
    'cancelled',
  ];

  static const List<String> activeStatuses = [
    'pending_driver_receipt',
    'driver_received_order',
    'in_transit',
    'failed',
    'rescheduled',
    'pending_pickup_point_delivery',
    'returning_to_store',
  ];

  static const List<String> completedStatuses = [
    'delivered',
    'dropped_at_pickup_point',
    'returned_to_store',
    'cancelled',
  ];

  static const Set<String> _completedStatuses = {
    'delivered',
    'dropped_at_pickup_point',
    'returned_to_store',
    'cancelled',
  };

  static const Map<String, String> _statusToEventType = {
    'created': 'order_created',
    'assigned': 'assigned_to_driver',
    'pending_driver_receipt': 'assigned_to_driver',
    'driver_received_order': 'picked_up',
    'picked_up': 'picked_up',
    'in_transit': 'in_transit',
    'delivered': 'delivered',
    'failed': 'delivery_failed',
    'pending_pickup_point_delivery': 'note_added',
    'rescheduled': 'note_added',
    'dropped_at_pickup_point': 'dropped_at_pickup_point',
    'returning_to_store': 'returning_to_store',
    'returned_to_store': 'returned_to_store',
    'cancelled': 'cancelled',
  };

  static const Map<String, List<String>> _nextStatuses = {
    // Canonical transitions used for validation at write time.
    // Includes compatibility aliases so older rows still move through the same workflow.
    'created': ['pending_driver_receipt', 'picked_up'],
    'ready_for_driver_pickup': ['pending_driver_receipt', 'picked_up'],
    'assigned': ['pending_driver_receipt', 'picked_up'],
    'pending_driver_receipt': ['driver_received_order', 'picked_up'],
    'driver_received_order': ['in_transit', 'customer_not_available'],
    'picked_up': ['in_transit'],
    'in_transit': ['delivered', 'failed'],
    'failed': [
      'rescheduled',
      'assigned',
      'dropped_at_pickup_point',
      'returning_to_store',
    ],
    'rescheduled': ['pending_driver_receipt', 'assigned'],
    'pending_pickup_point_delivery': ['dropped_at_pickup_point'],
    'returning_to_store': ['returned_to_store'],
    'dropped_at_pickup_point': [],
    'delivered': [],
    'returned_to_store': [],
    'cancelled': [],
  };

  static const Map<String, List<String>> _workflowTransitions = {
    'assigned': ['pending_driver_receipt'],
    'pending_driver_receipt': ['driver_received_order'],
    'driver_received_order': ['in_transit'],
    'in_transit': ['delivered', 'customer_not_available', 'failed'],
    'failed': ['rescheduled', 'dropped_at_pickup_point', 'returning_to_store'],
    'rescheduled': [],
    'pending_pickup_point_delivery': ['dropped_at_pickup_point'],
    'returning_to_store': ['returned_to_store'],
    'delivered': [],
    'dropped_at_pickup_point': [],
    'returned_to_store': [],
    'cancelled': [],
  };

  User? get currentUser => _client.auth.currentUser;

  bool isCompletedStatus(String status) {
    return _completedStatuses.contains(status.toLowerCase());
  }

  List<String> getAvailableStatusUpdates(String currentStatus) {
    return List<String>.from(
      _nextStatuses[currentStatus.toLowerCase()] ?? const [],
    );
  }

  String workflowStatusFromOrderStatus(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'created':
      case 'ready_for_driver_pickup':
      case 'assigned':
      case 'pending_driver_receipt':
        return 'pending_driver_receipt';
      case 'driver_received_order':
      case 'picked_up':
        return 'driver_received_order';
      default:
        return normalized;
    }
  }

  List<String> getAllowedWorkflowActions(String currentOrderStatus) {
    final workflowStatus = workflowStatusFromOrderStatus(currentOrderStatus);
    return List<String>.from(_workflowTransitions[workflowStatus] ?? const []);
  }

  String? mapWorkflowActionToOrderStatus(String action) {
    final normalized = action.toLowerCase();
    switch (normalized) {
      case 'pending_driver_receipt':
        return 'assigned';
      case 'driver_received_order':
        return 'picked_up';
      case 'rescheduled':
        return 'assigned';
      default:
        return orderStatuses.contains(normalized) ? normalized : null;
    }
  }

  Future<Map<String, int>> getDriverDeliveryCounts() async {
    final all = await getDriverDeliveries();

    final completed = all
        .where((delivery) => isCompletedStatus(delivery.status))
        .length;
    final active = all.length - completed;

    return {'assigned': all.length, 'active': active, 'completed': completed};
  }

  Future<List<DriverDelivery>> getDriverDeliveries({
    DeliveryBucket? bucket,
    String? status,
  }) async {
    final driverId = await _resolveCurrentDriverId();

    final assignmentRows = await _client
        .from('assignments')
        .select(
          'id, order_id, company_id, driver_id, assigned_at, completed_at',
        )
        .eq('driver_id', driverId)
        .order('assigned_at', ascending: false);

    final assignments = List<Map<String, dynamic>>.from(assignmentRows);
    final deliveries = await _hydrateDeliveriesFromAssignments(assignments);

    return deliveries.where((delivery) {
      final statusMatch =
          status == null || status == 'all' || delivery.status == status;
      if (!statusMatch) return false;

      if (bucket == null) return true;
      if (bucket == DeliveryBucket.active) {
        return !isCompletedStatus(delivery.status);
      }
      return isCompletedStatus(delivery.status);
    }).toList();
  }

  Future<DriverOrderDetails> getOrderDetails(String orderId) async {
    final driverId = await _resolveCurrentDriverId();

    final assignmentRows = await _client
        .from('assignments')
        .select(
          'id, order_id, company_id, driver_id, assigned_at, completed_at',
        )
        .eq('driver_id', driverId)
        .eq('order_id', orderId)
        .limit(1);
    final assignmentList = List<Map<String, dynamic>>.from(assignmentRows);
    final assignment = assignmentList.isEmpty ? null : assignmentList.first;

    if (assignment == null) {
      throw Exception('Order is not assigned to current driver');
    }

    final deliveries = await _hydrateDeliveriesFromAssignments([
      Map<String, dynamic>.from(assignment),
    ]);

    if (deliveries.isEmpty) {
      throw Exception('Order details not found');
    }

    final delivery = deliveries.first;

    final orderAddressRows = await _client
        .from('order_addresses')
        .select(
          'pickup_address_text, pickup_lat, pickup_lng, '
          'dropoff_address_text, dropoff_lat, dropoff_lng',
        )
        .eq('order_id', orderId)
        .limit(1);
    final orderAddressList = List<Map<String, dynamic>>.from(orderAddressRows);
    final orderAddress = orderAddressList.isEmpty
        ? null
        : orderAddressList.first;

    String? openingHours;
    final pickupOrderRows = (await _client
        .from('orders')
        .select(
          'pickup_point_id, destination_pickup_point_id, '
          'dropoff_type, status, customer_address_text, '
          'customer_lat, customer_lng, '
          'dropoff_location_lat, dropoff_location_lng',
        )
        .eq('id', orderId)
        .limit(1));
    final pickupOrderList = List<Map<String, dynamic>>.from(pickupOrderRows);
    final pickupPointId = pickupOrderList.isEmpty
        ? null
        : pickupOrderList.first;
    final hasBackupPickupPoint =
        (pickupPointId?['destination_pickup_point_id']?.toString().trim().isNotEmpty ??
        false);

    final pickupId = pickupPointId?['pickup_point_id']?.toString();
    final destinationPickupId =
        pickupPointId?['destination_pickup_point_id']?.toString();
    if (pickupId != null && pickupId.isNotEmpty) {
      final pickupRows = await _client
          .from('pickup_points')
          .select('opening_hours')
          .eq('id', pickupId)
          .limit(1);
      final pickupList = List<Map<String, dynamic>>.from(pickupRows);
      final pickup = pickupList.isEmpty ? null : pickupList.first;
      openingHours = pickup?['opening_hours']?.toString();
    }
    Map<String, dynamic>? destinationPickup;
    if (destinationPickupId != null && destinationPickupId.isNotEmpty) {
      destinationPickup = await _client
          .from('pickup_points')
          .select('id, name, address_text, lat, lng')
          .eq('id', destinationPickupId)
          .maybeSingle();
    }

    final eventRows = await _client
        .from('order_events')
        .select('id, order_id, event_type, note, created_at, created_by')
        .eq('order_id', orderId)
        .order('created_at', ascending: true);

    final eventsRaw = List<Map<String, dynamic>>.from(eventRows);
    final creatorIds = eventsRaw
        .map((event) => event['created_by']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    Map<String, Map<String, dynamic>> creatorsById = {};
    if (creatorIds.isNotEmpty) {
      final creatorRows = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', creatorIds);

      creatorsById = {
        for (final row in List<Map<String, dynamic>>.from(creatorRows))
          row['id'].toString(): row,
      };
    }

    final events = eventsRaw.map((row) {
      final createdById = row['created_by']?.toString();
      final createdByName = createdById == null
          ? null
          : creatorsById[createdById]?['full_name']?.toString();

      return DeliveryTimelineEvent(
        id: row['id'].toString(),
        orderId: row['order_id'].toString(),
        eventType: row['event_type']?.toString() ?? 'note_added',
        note: row['note']?.toString(),
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
        createdById: createdById,
        createdByName: createdByName,
      );
    }).toList();

    final orderStatus = (pickupPointId?['status']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final movedToBackupStatuses = const {
      'pending_pickup_point_delivery',
      'dropped_at_pickup_point',
    };
    final backupIsActiveDropoff = hasBackupPickupPoint &&
        movedToBackupStatuses.contains(orderStatus) &&
        destinationPickup != null;
    final activeDropoffLat = backupIsActiveDropoff
        ? _toDouble(destinationPickup['lat'])
        : (_toDouble(pickupPointId?['dropoff_location_lat']) ??
              _toDouble(orderAddress?['dropoff_lat']) ??
              _toDouble(pickupPointId?['customer_lat']));
    final activeDropoffLng = backupIsActiveDropoff
        ? _toDouble(destinationPickup['lng'])
        : (_toDouble(pickupPointId?['dropoff_location_lng']) ??
              _toDouble(orderAddress?['dropoff_lng']) ??
              _toDouble(pickupPointId?['customer_lng']));
    final activeDropoffAddress = backupIsActiveDropoff
        ? _firstNonEmpty([
            destinationPickup['address_text'],
            destinationPickup['name'],
          ])
        : _firstNonEmpty([
            pickupPointId?['customer_address_text'],
            orderAddress?['dropoff_address_text'],
            orderAddress?['dropoff_address'],
            delivery.dropoffAddress,
          ]);

    return DriverOrderDetails(
      delivery: delivery,
      orderNotes: delivery.notes,
      dropoffAddress: activeDropoffAddress,
      dropoffLat: activeDropoffLat,
      dropoffLng: activeDropoffLng,
      hasBackupPickupPoint: hasBackupPickupPoint,
      backupPickupPointName: destinationPickup?['name']?.toString(),
      backupPickupPointAddress: destinationPickup?['address_text']?.toString(),
      backupPickupPointLat: _toDouble(destinationPickup?['lat']),
      backupPickupPointLng: _toDouble(destinationPickup?['lng']),
      homeDropoffAddress: _firstNonEmpty([
        pickupPointId?['customer_address_text'],
        orderAddress?['dropoff_address_text'],
      ]),
      homeDropoffLat: _toDouble(pickupPointId?['customer_lat']),
      homeDropoffLng: _toDouble(pickupPointId?['customer_lng']),
      pickupOpeningHours: openingHours,
      events: events,
    );
  }

  Future<void> addDriverNoteEvent({
    required String orderId,
    required String note,
  }) async {
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) {
      throw Exception('Note is empty');
    }

    final driverId = await _resolveCurrentDriverId();
    final existingRows = await _client
        .from('assignments')
        .select('order_id')
        .eq('order_id', orderId)
        .eq('driver_id', driverId)
        .limit(1);
    final existingList = List<Map<String, dynamic>>.from(existingRows);
    final existing = existingList.isEmpty ? null : existingList.first;

    if (existing == null) {
      throw Exception('Order is not assigned to current driver');
    }

    await _client.from('order_events').insert({
      'order_id': orderId,
      'event_type': 'note_added',
      'created_by': currentUser?.id,
      'note': trimmedNote,
    });
  }

  Future<List<Map<String, dynamic>>> getAvailablePickupPoints() async {
    final rows = await _client
        .from('pickup_points')
        .select('id, name, address_text')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> confirmPickup({
    required String orderId,
    String? pickupLabel,
  }) async {
    await _ensureCanAcceptOrder(orderId: orderId);
    final trimmedLabel = pickupLabel?.trim();
    final note = trimmedLabel == null || trimmedLabel.isEmpty
        ? 'Driver accepted the order.'
        : 'Driver accepted the order. Picked up from $trimmedLabel';

    await updateOrderStatus(
      orderId: orderId,
      newStatus: 'driver_received_order',
      note: note,
    );
  }

  Future<void> confirmDropoffAtPickupPoint({required String orderId}) async {
    final order = await _loadOrderWithAddress(orderId);
    if (order == null) {
      throw Exception('Order not found');
    }

    final pickupPointId =
        order['order']['destination_pickup_point_id']?.toString() ??
        order['order']['pickup_point_id']?.toString();
    if (pickupPointId == null || pickupPointId.isEmpty) {
      throw Exception('No pickup point is assigned for this order.');
    }

    final pickupPoint = await _client
        .from('pickup_points')
        .select('name, address_text')
        .eq('id', pickupPointId)
        .maybeSingle();

    final pickupPointName = _firstNonEmpty([
      pickupPoint?['name'],
      order['order']['dropoff_name'],
    ]);
    final pickupPointAddress = _firstNonEmpty([
      pickupPoint?['address_text'],
      order['address']?['dropoff_address_text'],
      order['order']['dropoff_address_text'],
    ]);
    final note = pickupPointName == null
        ? 'Dropped at pickup point'
        : 'Dropped at pickup point: $pickupPointName'
              '${pickupPointAddress == null ? '' : ' ($pickupPointAddress)'}';

    await updateOrderStatus(
      orderId: orderId,
      newStatus: 'dropped_at_pickup_point',
      note: note,
    );
  }

  Future<void> redirectHomeDeliveryToNearestPickupPoint({
    required String orderId,
  }) async {
    final driverId = await _resolveCurrentDriverId();
    final orderWithAddress = await _loadOrderWithAddress(orderId);
    if (orderWithAddress == null) {
      throw Exception('Order not found');
    }

    final order = orderWithAddress['order']!;
    final address = orderWithAddress['address'];
    final currentStatus = (order['status']?.toString() ?? 'created')
        .toLowerCase();
    if (!{
      'in_transit',
      'driver_received_order',
    }.contains(workflowStatusFromOrderStatus(currentStatus))) {
      throw Exception(
        'Customer unavailable fallback is only allowed while the order is active.',
      );
    }

    if (_isPickupPointDropoff(order)) {
      throw Exception(
        'This order is already assigned to a pickup-point dropoff.',
      );
    }

    final customerLat =
        _toDouble(order['dropoff_location_lat']) ??
        _toDouble(order['customer_lat']) ??
        _toDouble(address?['dropoff_lat']);
    final customerLng =
        _toDouble(order['dropoff_location_lng']) ??
        _toDouble(order['customer_lng']) ??
        _toDouble(address?['dropoff_lng']);
    if (customerLat == null || customerLng == null) {
      throw Exception('Customer home coordinates are missing.');
    }

    final configuredBackupId = order['destination_pickup_point_id']?.toString();
    if (configuredBackupId == null || configuredBackupId.isEmpty) {
      throw Exception('No backup pickup point is configured for this order.');
    }
    final backupRows = await _client
        .from('pickup_points')
        .select('id, name, address_text, lat, lng, city, area, is_active')
        .eq('id', configuredBackupId)
        .limit(1);
    final backupList = List<Map<String, dynamic>>.from(backupRows);
    final backup = backupList.isEmpty ? null : backupList.first;
    final backupLat = _toDouble(backup?['lat']);
    final backupLng = _toDouble(backup?['lng']);
    if (backup == null || backup['is_active'] != true) {
      throw Exception('Backup pickup point is missing or inactive.');
    }
    if (backupLat == null || backupLng == null) {
      throw Exception('Backup pickup point location is missing.');
    }

    final pickupPointId = backup['id'].toString();
    final pickupPointName = backup['name']?.toString() ?? 'Pickup point';
    final pickupPointAddress = backup['address_text']?.toString();
    final trackingCode = order['tracking_code']?.toString() ?? '';
    final now = DateTime.now().toUtc().toIso8601String();
    const newStatus = 'pending_pickup_point_delivery';
    debugPrint(
      '[OPTION2_REDIRECT_ATTEMPT] authUser=${_client.auth.currentUser?.id} '
      'order=$orderId tracking=$trackingCode status=$currentStatus '
      'destinationPickup=$configuredBackupId backupLat=$backupLat backupLng=$backupLng',
    );
    try {
      await _client
          .from('orders')
          .update({
            'status': newStatus,
            'dropoff_location_lat': backupLat,
            'dropoff_location_lng': backupLng,
            'updated_at': now,
          })
          .eq('id', orderId)
          .eq('status', currentStatus);
    } on PostgrestException catch (e) {
      debugPrint(
        '[OPTION2_REDIRECT_ORDERS_UPDATE_ERROR] code=${e.code} message=${e.message} '
        'details=${e.details} hint=${e.hint}',
      );
      if (e.code == '42501') {
        throw Exception(
          'Permission error on orders update (42501). Driver is not allowed to move this assigned order to pending_pickup_point_delivery.',
        );
      }
      rethrow;
    }

    try {
      await _client.from('order_addresses').upsert(
        {
          'order_id': orderId,
          'dropoff_address_text': pickupPointAddress ?? pickupPointName,
          'dropoff_lat': backupLat,
          'dropoff_lng': backupLng,
        },
        onConflict: 'order_id',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '[OPTION2_REDIRECT_ORDER_ADDRESSES_SYNC_ERROR] code=${e.code} message=${e.message} '
        'details=${e.details} hint=${e.hint}',
      );
      if (e.code == '42501') {
        throw Exception(
          'Order moved, but order_addresses sync failed (42501). Apply order_addresses RLS migration.',
        );
      }
      rethrow;
    }

    final latestRows = await _client
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .limit(1);
    final latestList = List<Map<String, dynamic>>.from(latestRows);
    final latestStatus = latestList.isEmpty
        ? ''
        : (latestList.first['status']?.toString() ?? '').toLowerCase();
    if (latestStatus != newStatus) {
      throw Exception(
        'Order status changed to "$latestStatus". Refresh the order before retrying.',
      );
    }

    final note =
        'Customer unavailable. Order moved to backup pickup point: $pickupPointName'
        '${pickupPointAddress == null ? '' : ' ($pickupPointAddress)'}';
    debugPrint(
      '[OPTION2_MOVE] order=$orderId tracking=${order['tracking_code']} '
      'backupPickup=$pickupPointId lat=$backupLat lng=$backupLng '
      'oldHome=$customerLat,$customerLng newStatus=$newStatus',
    );

    try {
      await _client.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'note_added',
        'created_by': currentUser?.id,
        'note': note,
        'metadata': {
          'reason': 'customer_not_available',
          'moved_to_backup_pickup_point': true,
          'backup_pickup_point_id': pickupPointId,
          'backup_pickup_point_name': pickupPointName,
          'backup_pickup_point_lat': backupLat,
          'backup_pickup_point_lng': backupLng,
          'previous_customer_lat': customerLat,
          'previous_customer_lng': customerLng,
        },
      });
    } catch (_) {}

    final companyId = _firstNonEmpty([
      order['delivery_company_id'],
      order['company_id'],
      await _loadAssignmentCompanyId(orderId: orderId, driverId: driverId),
    ]);
    await _retargetPendingDropoffRouteStop(
      orderId: orderId,
      driverId: driverId,
      companyId: companyId ?? '',
      pickupPoint: backup,
    );
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? note,
  }) async {
    final requestedStatus = newStatus.toLowerCase();
    final normalizedNewStatus =
        mapWorkflowActionToOrderStatus(requestedStatus) ?? requestedStatus;
    if (!orderStatuses.contains(normalizedNewStatus)) {
      throw Exception('Invalid order status: $newStatus');
    }

    final driverId = await _resolveCurrentDriverId();
    final existingRows = await _client
        .from('assignments')
        .select('order_id')
        .eq('order_id', orderId)
        .eq('driver_id', driverId)
        .limit(1);
    final existingList = List<Map<String, dynamic>>.from(existingRows);
    final existing = existingList.isEmpty ? null : existingList.first;

    if (existing == null) {
      throw Exception('Order is not assigned to current driver');
    }

    final currentOrderRows = await _client
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .limit(1);
    final currentOrderList = List<Map<String, dynamic>>.from(currentOrderRows);
    final currentOrder = currentOrderList.isEmpty
        ? null
        : currentOrderList.first;

    if (currentOrder == null) {
      throw Exception('Order not found');
    }

    final currentStatus = (currentOrder['status']?.toString() ?? 'created')
        .toLowerCase();
    if (currentStatus == normalizedNewStatus) {
      return;
    }
    final allowed = getAvailableStatusUpdates(currentStatus);
    if (!allowed.contains(normalizedNewStatus)) {
      throw Exception(
        'Invalid status transition from $currentStatus to $normalizedNewStatus',
      );
    }

    final eventType = _statusToEventType[normalizedNewStatus];
    if (eventType == null) {
      throw Exception('No mapped event for status: $normalizedNewStatus');
    }

    final statusUpdatePayload = {
      'status': normalizedNewStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Optimistic update first: only if status is still what we just read.
    await _client
        .from('orders')
        .update(statusUpdatePayload)
        .eq('id', orderId)
        .eq('status', currentStatus);

    // Re-read to verify effect.
    final latestAfterOptimisticRows = await _client
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .limit(1);
    final latestAfterOptimisticList = List<Map<String, dynamic>>.from(
      latestAfterOptimisticRows,
    );
    final latestAfterOptimistic = latestAfterOptimisticList.isEmpty
        ? ''
        : (latestAfterOptimisticList.first['status']?.toString() ?? '')
              .toLowerCase();

    if (latestAfterOptimistic != normalizedNewStatus) {
      // If new transition is still valid from the latest status, retry without optimistic filter.
      final latestAllowed = getAvailableStatusUpdates(latestAfterOptimistic);
      if (latestAllowed.contains(normalizedNewStatus)) {
        await _client
            .from('orders')
            .update(statusUpdatePayload)
            .eq('id', orderId);

        final verifyRows = await _client
            .from('orders')
            .select('status')
            .eq('id', orderId)
            .limit(1);
        final verifyList = List<Map<String, dynamic>>.from(verifyRows);
        final verifyStatus = verifyList.isEmpty
            ? ''
            : (verifyList.first['status']?.toString() ?? '').toLowerCase();

        if (verifyStatus != normalizedNewStatus) {
          throw Exception(
            'Status update was rejected by server rules for this order.',
          );
        }
      } else if (latestAfterOptimistic == normalizedNewStatus) {
        // Already applied elsewhere.
      } else {
        throw Exception(
          'Order status changed to "$latestAfterOptimistic". Refresh to continue.',
        );
      }
    }

    final user = currentUser;
    try {
      await _client.from('order_events').insert({
        'order_id': orderId,
        'event_type': eventType,
        'created_by': user?.id,
        'note': note?.trim().isEmpty ?? true ? null : note!.trim(),
      });
    } catch (_) {
      // Keep status transition successful even if event logging policy blocks insert.
    }

    await _markRouteStopCompleted(
      orderId: orderId,
      driverId: driverId,
      normalizedNewStatus: normalizedNewStatus,
    );

    if (normalizedNewStatus == 'picked_up') {
      try {
        await _client
            .from('assignments')
            .update({'accepted_at': DateTime.now().toUtc().toIso8601String()})
            .eq('order_id', orderId)
            .eq('driver_id', driverId);
      } catch (_) {}
    }

    if (isCompletedStatus(normalizedNewStatus)) {
      try {
        await _client
            .from('assignments')
            .update({'completed_at': DateTime.now().toUtc().toIso8601String()})
            .eq('order_id', orderId);
      } catch (_) {}
    }

    // "Rescheduled" sends the order back to company/assignment queue.
    if (requestedStatus == 'rescheduled') {
      try {
        await _client
            .from('assignments')
            .update({
              'driver_id': null,
              'accepted_at': null,
              'completed_at': null,
            })
            .eq('order_id', orderId)
            .eq('driver_id', driverId);
      } catch (_) {}
    }

    // Release driver only when return process is fully completed.
    if (normalizedNewStatus == 'returned_to_store') {
      try {
        await _client
            .from('assignments')
            .update({'driver_id': null, 'accepted_at': null})
            .eq('order_id', orderId)
            .eq('driver_id', driverId);
      } catch (_) {}
    }
  }

  Future<void> _markRouteStopCompleted({
    required String orderId,
    required String driverId,
    required String normalizedNewStatus,
  }) async {
    try {
      final completedAt = DateTime.now().toUtc().toIso8601String();
      if (normalizedNewStatus == 'picked_up') {
        await _client
            .from('driver_route_stops')
            .update({'completed_at': completedAt, 'updated_at': completedAt})
            .eq('order_id', orderId)
            .eq('driver_id', driverId)
            .eq('stop_type', 'pickup')
            .isFilter('completed_at', null);
      }

      if (isCompletedStatus(normalizedNewStatus)) {
        await _client
            .from('driver_route_stops')
            .update({'completed_at': completedAt, 'updated_at': completedAt})
            .eq('order_id', orderId)
            .eq('driver_id', driverId)
            .eq('stop_type', 'dropoff')
            .isFilter('completed_at', null);
      }
    } catch (_) {
      // Route tables are optional until the automated-assignment migration is applied.
    }
  }

  Future<Map<String, dynamic>?> _loadOrderWithAddress(String orderId) async {
    final orderRows = await _client
        .from('orders')
        .select('*')
        .eq('id', orderId)
        .limit(1);
    final orderList = List<Map<String, dynamic>>.from(orderRows);
    if (orderList.isEmpty) return null;

    final addressRows = await _client
        .from('order_addresses')
        .select('*')
        .eq('order_id', orderId)
        .limit(1);
    final addressList = List<Map<String, dynamic>>.from(addressRows);

    return {
      'order': orderList.first,
      'address': addressList.isEmpty ? null : addressList.first,
    };
  }

  Future<String?> _loadAssignmentCompanyId({
    required String orderId,
    required String driverId,
  }) async {
    final rows = await _client
        .from('assignments')
        .select('company_id')
        .eq('order_id', orderId)
        .eq('driver_id', driverId)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) return null;
    return list.first['company_id']?.toString();
  }

  Future<Map<String, dynamic>?> _findNearestCompanyPickupPoint({
    required String companyId,
    required double lat,
    required double lng,
  }) async {
    final rows = await _client
        .from('pickup_points')
        .select('id, company_id, name, address_text, lat, lng, is_active')
        .eq('company_id', companyId)
        .eq('is_active', true);
    final points = List<Map<String, dynamic>>.from(rows)
        .where(
          (point) =>
              _toDouble(point['lat']) != null &&
              _toDouble(point['lng']) != null,
        )
        .toList();
    if (points.isEmpty) return null;

    Map<String, dynamic>? bestPoint;
    double? bestDistance;
    for (final point in points) {
      final pointLat = _toDouble(point['lat']);
      final pointLng = _toDouble(point['lng']);
      if (pointLat == null || pointLng == null) continue;

      final distance = _distanceMeters(
        startLat: lat,
        startLng: lng,
        endLat: pointLat,
        endLng: pointLng,
      );
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestPoint = point;
      }
    }

    return bestPoint;
  }

  Future<void> _retargetPendingDropoffRouteStop({
    required String orderId,
    required String driverId,
    required String companyId,
    required Map<String, dynamic> pickupPoint,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _client
          .from('driver_route_stops')
          .update({
            'location_name': pickupPoint['name']?.toString() ?? 'Pickup point',
            'location_address': pickupPoint['address_text']?.toString(),
            'lat': _toDouble(pickupPoint['lat']),
            'lng': _toDouble(pickupPoint['lng']),
            'service_seconds': 4 * 60,
            'updated_at': now,
          })
          .eq('order_id', orderId)
          .eq('driver_id', driverId)
          .eq('company_id', companyId)
          .eq('stop_type', 'dropoff')
          .isFilter('completed_at', null);

      await _client
          .from('driver_routes')
          .update({'updated_at': now})
          .eq('driver_id', driverId)
          .eq('company_id', companyId)
          .eq('status', 'active');
    } catch (_) {
      // Route persistence is best-effort until every environment has route tables.
    }
  }

  double _distanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degreesToRadians(endLat - startLat);
    final dLng = _degreesToRadians(endLng - startLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(startLat)) *
            math.cos(_degreesToRadians(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180.0);

  Future<void> _ensureCanAcceptOrder({required String orderId}) async {
    final driverId = await _resolveCurrentDriverId();
    final orderRows = await _client
        .from('orders')
        .select('id, item_count, estimated_weight, estimated_volume, status')
        .eq('id', orderId)
        .limit(1);
    final orderList = List<Map<String, dynamic>>.from(orderRows);
    if (orderList.isEmpty) throw Exception('Order not found');
    final order = orderList.first;

    final driverRows = await _client
        .from('drivers')
        .select('capacity_item_count, capacity_weight, capacity_volume')
        .eq('id', driverId)
        .limit(1);
    final driverList = List<Map<String, dynamic>>.from(driverRows);
    if (driverList.isEmpty) throw Exception('Driver profile not found');
    final driver = driverList.first;

    final assignmentRows = await _client
        .from('assignments')
        .select('order_id, completed_at')
        .eq('driver_id', driverId)
        .isFilter('completed_at', null);
    final activeAssignments = List<Map<String, dynamic>>.from(assignmentRows);
    final activeOrderIds = activeAssignments
        .map((row) => row['order_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty && id != orderId)
        .toSet()
        .toList();

    var currentItems = 0;
    var currentWeight = 0.0;
    var currentVolume = 0.0;
    if (activeOrderIds.isNotEmpty) {
      final activeOrdersRows = await _client
          .from('orders')
          .select('id, status, item_count, estimated_weight, estimated_volume')
          .inFilter('id', activeOrderIds);
      final activeOrders = List<Map<String, dynamic>>.from(activeOrdersRows);
      const inactiveStatuses = {
        'delivered',
        'cancelled',
        'dropped_at_pickup_point',
        'returned_to_store',
        'returning_to_store',
      };
      for (final active in activeOrders) {
        final status = (active['status']?.toString() ?? '').toLowerCase();
        if (inactiveStatuses.contains(status)) continue;
        currentItems += _toInt(active['item_count']) ?? 1;
        currentWeight += _toDouble(active['estimated_weight']) ?? 0.0;
        currentVolume += _toDouble(active['estimated_volume']) ?? 0.0;
      }
    }

    final orderItems = _toInt(order['item_count']) ?? 1;
    final orderWeight = _toDouble(order['estimated_weight']) ?? 0.0;
    final orderVolume = _toDouble(order['estimated_volume']) ?? 0.0;
    final capItems = _toInt(driver['capacity_item_count']) ?? 0;
    final capWeight = _toDouble(driver['capacity_weight']) ?? 0.0;
    final capVolume = _toDouble(driver['capacity_volume']) ?? 0.0;

    final exceeds = (currentItems + orderItems > capItems) ||
        (currentWeight + orderWeight > capWeight) ||
        (currentVolume + orderVolume > capVolume);
    if (exceeds) {
      throw Exception('Cannot accept this order. Driver capacity would be exceeded.');
    }
  }

  Future<String> _resolveCurrentDriverId() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    Map<String, dynamic>? byProfile;
    try {
      final byProfileRows = await _client
          .from('drivers')
          .select('id')
          .eq('profile_id', user.id)
          .limit(1);
      final byProfileList = List<Map<String, dynamic>>.from(byProfileRows);
      byProfile = byProfileList.isEmpty ? null : byProfileList.first;
    } catch (_) {
      byProfile = null;
    }

    if (byProfile != null && byProfile['id'] != null) {
      return byProfile['id'].toString();
    }

    final byIdRows = await _client
        .from('drivers')
        .select('id')
        .eq('id', user.id)
        .limit(1);
    final byIdList = List<Map<String, dynamic>>.from(byIdRows);
    final byId = byIdList.isEmpty ? null : byIdList.first;

    if (byId != null && byId['id'] != null) {
      return byId['id'].toString();
    }

    throw Exception('Driver record not found for current profile');
  }

  Future<List<DriverDelivery>> _hydrateDeliveriesFromAssignments(
    List<Map<String, dynamic>> assignments,
  ) async {
    if (assignments.isEmpty) {
      return [];
    }

    final orderIds = assignments
        .map((assignment) => assignment['order_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (orderIds.isEmpty) {
      return [];
    }

    final orderRows = await _client
        .from('orders')
        .select('*')
        .inFilter('id', orderIds);

    final orders = List<Map<String, dynamic>>.from(orderRows);
    final ordersById = _keyById(orders);
    final orderAddressRows = await _client
        .from('order_addresses')
        .select('*')
        .inFilter('order_id', orderIds);
    final orderAddressByOrderId = {
      for (final row in List<Map<String, dynamic>>.from(orderAddressRows))
        if (row['order_id'] != null) row['order_id'].toString(): row,
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

    final merchantIds = <String>{
      for (final order in orders)
        ...[
          order['merchant_id']?.toString().trim(),
        ].whereType<String>().where((id) => id.isNotEmpty),
    }.toList();

    final customerIds = orders
        .map((order) => order['customer_profile_id']?.toString().trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final branchIds = orders
        .map((order) => order['branch_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final pickupPoints = pickupIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('pickup_points')
                .select('id, name, address_text, lat, lng')
                .inFilter('id', pickupIds),
          );

    final merchants = merchantIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('merchant_businesses')
                .select('id, name')
                .inFilter('id', merchantIds),
          );

    final customers = customerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('profiles')
                .select('id, full_name, phone')
                .inFilter('id', customerIds),
          );

    final branches = branchIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('merchant_branches')
                .select('*')
                .inFilter('id', branchIds),
          );

    final pickupById = _keyById(pickupPoints);
    final merchantById = _keyById(merchants);
    final customerById = _keyById(customers);
    final branchById = _keyById(branches);

    final result = <DriverDelivery>[];

    for (final assignment in assignments) {
      final orderId = assignment['order_id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        continue;
      }

      final order = ordersById[orderId];
      if (order == null) {
        continue;
      }
      final orderAddress = orderAddressByOrderId[orderId];

      final pickup = pickupById[order['pickup_point_id']?.toString()];
      final destinationPickup =
          pickupById[order['destination_pickup_point_id']?.toString()];
      final branch = branchById[order['branch_id']?.toString()];
      final isPickupPointDropoff = _isPickupPointDropoff(order);
      final status = (order['status']?.toString() ?? '').toLowerCase();
      final isHomeOption2Active =
          (order['dropoff_type']?.toString().toLowerCase() == 'home') &&
          destinationPickup != null &&
          const {
            'pending_pickup_point_delivery',
            'dropped_at_pickup_point',
          }.contains(status);
      final merchantKey = _firstNonEmpty([
        order['merchant_id'],
        branch?['merchant_id'],
      ]);
      final merchant = merchantKey == null ? null : merchantById[merchantKey];
      final customerProfileId = order['customer_profile_id']?.toString().trim();
      final customer = customerById[customerProfileId];
      final customerName = _firstNonEmpty([
        customer?['full_name'],
        order['customer_name'],
        order['recipient_name'],
        order['receiver_name'],
        order['contact_name'],
        order['consignee_name'],
        orderAddress?['customer_name'],
        orderAddress?['recipient_name'],
        orderAddress?['receiver_name'],
        orderAddress?['contact_name'],
        orderAddress?['consignee_name'],
      ]);
      final customerPhone = _firstNonEmpty([
        customer?['phone'],
        order['customer_phone'],
        order['recipient_phone'],
        order['receiver_phone'],
        order['contact_phone'],
        order['consignee_phone'],
        order['phone'],
        orderAddress?['customer_phone'],
        orderAddress?['recipient_phone'],
        orderAddress?['receiver_phone'],
        orderAddress?['contact_phone'],
        orderAddress?['consignee_phone'],
        orderAddress?['phone'],
      ]);
      final customerEmail = _firstNonEmpty([
        order['customer_email'],
        order['recipient_email'],
        order['receiver_email'],
        order['contact_email'],
        order['consignee_email'],
        orderAddress?['customer_email'],
        orderAddress?['recipient_email'],
        orderAddress?['receiver_email'],
        orderAddress?['contact_email'],
        orderAddress?['consignee_email'],
        orderAddress?['email'],
      ]);
      final pickupName =
          _firstNonEmpty([
            pickup?['name'],
            order['pickup_name'],
            orderAddress?['pickup_name'],
            branch?['name'],
            order['merchant_name'],
            merchant?['name'],
          ]) ??
          'Pickup location';
      final pickupAddress =
          _firstNonEmpty([
            pickup?['address_text'],
            orderAddress?['pickup_address_text'],
            order['pickup_address_text'],
            order['pickup_address'],
            branch?['address_text'],
          ]) ??
          'Not provided';
      final pickupLat =
          _toDouble(order['pickup_location_lat']) ??
          _toDouble(orderAddress?['pickup_lat']) ??
          _toDouble(pickup?['lat']) ??
          _toDouble(order['pickup_lat']) ??
          _toDouble(branch?['lat']);
      final pickupLng =
          _toDouble(order['pickup_location_lng']) ??
          _toDouble(orderAddress?['pickup_lng']) ??
          _toDouble(pickup?['lng']) ??
          _toDouble(order['pickup_lng']) ??
          _toDouble(branch?['lng']);
      final destinationPickupName = destinationPickup == null
          ? null
          : destinationPickup['name'];
      final destinationPickupAddress = destinationPickup == null
          ? null
          : destinationPickup['address_text'];
      final destinationPickupLat = _toDouble(
        destinationPickup == null ? null : destinationPickup['lat'],
      );
      final destinationPickupLng = _toDouble(
        destinationPickup == null ? null : destinationPickup['lng'],
      );
      final pickupPointDropoffName = isHomeOption2Active
          ? destinationPickupName
          : (isPickupPointDropoff
                ? (destinationPickupName ?? pickup?['name'])
                : null);
      final pickupPointDropoffAddress = isHomeOption2Active
          ? destinationPickupAddress
          : (isPickupPointDropoff
                ? (destinationPickupAddress ?? pickup?['address_text'])
                : null);
      final dropoffName =
          _firstNonEmpty([
            pickupPointDropoffName,
            order['dropoff_name'],
            order['customer_name'],
            customer?['full_name'],
          ]) ??
          (isPickupPointDropoff ? 'Pickup point dropoff' : 'Dropoff location');
      final dropoffAddress = _firstNonEmpty([
        pickupPointDropoffAddress,
        order['customer_address_text'],
        order['dropoff_address_text'],
        orderAddress?['dropoff_address_text'],
        orderAddress?['dropoff_address'],
        order['dropoff_address'],
        order['delivery_address'],
        order['address'],
      ]);
      double? dropoffLat = _toDouble(
        isHomeOption2Active
            ? (destinationPickupLat ??
                  order['dropoff_location_lat'] ??
                  orderAddress?['dropoff_lat'] ??
                  order['customer_lat'])
            : (isPickupPointDropoff
                ? (order['dropoff_location_lat'] ??
                      orderAddress?['dropoff_lat'] ??
                      (destinationPickupLat ?? pickup?['lat']) ??
                      order['customer_lat'])
                : (order['dropoff_location_lat'] ??
                      orderAddress?['dropoff_lat'] ??
                      order['customer_lat'])),
      );
      double? dropoffLng = _toDouble(
        isHomeOption2Active
            ? (destinationPickupLng ??
                  order['dropoff_location_lng'] ??
                  orderAddress?['dropoff_lng'] ??
                  order['customer_lng'])
            : (isPickupPointDropoff
                ? (order['dropoff_location_lng'] ??
                      orderAddress?['dropoff_lng'] ??
                      (destinationPickupLng ?? pickup?['lng']) ??
                      order['customer_lng'])
                : (order['dropoff_location_lng'] ??
                      orderAddress?['dropoff_lng'] ??
                      order['customer_lng'])),
      );
      debugPrint(
        '[DRIVER_ACTIVE_DESTINATION] order=$orderId status=$status '
        'activeLat=$dropoffLat activeLng=$dropoffLng '
        'activeType=${isHomeOption2Active ? "backup_option_2" : (isPickupPointDropoff ? "pickup_point" : "home")}',
      );
      result.add(
        DriverDelivery(
          assignmentId: assignment['id'].toString(),
          orderId: orderId,
          companyId: assignment['company_id']?.toString(),
          driverId: assignment['driver_id']?.toString(),
          assignedAt: _parseDate(assignment['assigned_at']),
          completedAt: _parseDate(assignment['completed_at']),
          trackingCode: order['tracking_code']?.toString() ?? orderId,
          status: _normalizeDriverVisibleStatus(order['status']?.toString()),
          notes: order['notes']?.toString(),
          merchantName:
              _firstNonEmpty([
                merchant?['name'],
                order['merchant_name'],
                order['business_name'],
                branch?['merchant_name'],
                branch?['business_name'],
                branch?['name'],
              ]) ??
              'Unknown merchant',
          pickupPointName: pickupName,
          pickupAddress: pickupAddress,
          pickupLat: pickupLat,
          pickupLng: pickupLng,
          pickupPointId: order['pickup_point_id']?.toString(),
          dropoffType: order['dropoff_type']?.toString(),
          dropoffName: isHomeOption2Active
              ? 'Backup Pickup Point / Option 2'
              : dropoffName,
          dropoffAddress: dropoffAddress,
          dropoffLat: dropoffLat,
          dropoffLng: dropoffLng,
          customerName: customerName ?? 'Not provided',
          customerPhone: customerPhone ?? 'Not provided',
          customerEmail: customerEmail,
          itemCount: _toInt(order['item_count'] ?? order['items_count']),
          estimatedWeightKg: _toDouble(
            order['estimated_weight'] ?? order['estimated_weight_kg'],
          ),
          estimatedVolumeCm3: _toDouble(
            order['estimated_volume'] ?? order['estimated_volume_cm3'],
          ),
          branchName: branch?['name']?.toString(),
          branchAddress: branch?['address_text']?.toString(),
          branchLat: _toDouble(branch?['lat']),
          branchLng: _toDouble(branch?['lng']),
        ),
      );
    }

    return result;
  }

  String _normalizeDriverVisibleStatus(String? rawStatus) {
    final normalized = (rawStatus ?? 'created').toLowerCase();
    switch (normalized) {
      case 'created':
      case 'ready_for_driver_pickup':
      case 'assigned':
      case 'pending_driver_receipt':
        return 'pending_driver_receipt';
      case 'picked_up':
      case 'driver_received_order':
        return 'driver_received_order';
      default:
        return normalized;
    }
  }

  bool _isPickupPointDropoff(Map<String, dynamic> order) {
    final dropoffType = order['dropoff_type']?.toString().toLowerCase();
    return dropoffType == 'pickup_point' ||
        dropoffType == 'pickup point' ||
        dropoffType == 'pickup_point_specific';
  }

  Map<String, Map<String, dynamic>> _keyById(List<Map<String, dynamic>> rows) {
    return {
      for (final row in rows)
        if (row['id'] != null) row['id'].toString(): row,
    };
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != '-') {
        return text;
      }
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
