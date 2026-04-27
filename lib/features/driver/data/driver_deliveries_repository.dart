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
    'driver_received_order': ['in_transit'],
    'picked_up': ['in_transit'],
    'in_transit': ['delivered', 'failed'],
    'failed': [
      'returning_to_store',
    ],
    'rescheduled': ['pending_driver_receipt', 'assigned'],
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
    'failed': ['returning_to_store'],
    'rescheduled': [],
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
        .select('dropoff_address_text, dropoff_lat, dropoff_lng')
        .eq('order_id', orderId)
        .limit(1);
    final orderAddressList = List<Map<String, dynamic>>.from(orderAddressRows);
    final orderAddress = orderAddressList.isEmpty
        ? null
        : orderAddressList.first;

    String? openingHours;
    final pickupOrderRows = (await _client
        .from('orders')
        .select('pickup_point_id, notes')
        .eq('id', orderId)
        .limit(1));
    final pickupOrderList = List<Map<String, dynamic>>.from(pickupOrderRows);
    final pickupPointId = pickupOrderList.isEmpty
        ? null
        : pickupOrderList.first;

    final orderNotes = pickupPointId?['notes']?.toString();

    final pickupId = pickupPointId?['pickup_point_id']?.toString();
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

    return DriverOrderDetails(
      delivery: delivery,
      orderNotes: orderNotes ?? delivery.notes,
      dropoffAddress: _firstNonEmpty([
        orderAddress?['dropoff_address_text'],
        orderAddress?['dropoff_address'],
        delivery.dropoffAddress,
      ]),
      dropoffLat: _toDouble(orderAddress?['dropoff_lat']),
      dropoffLng: _toDouble(orderAddress?['dropoff_lng']),
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

  Future<void> confirmPickupWithPoint({
    required String orderId,
    required String pickupPointId,
    String? pickupPointName,
  }) async {
    final note = (pickupPointName == null || pickupPointName.trim().isEmpty)
        ? null
        : 'Picked up from $pickupPointName';

    // Use the same strict transition gate used by all status updates.
    await updateOrderStatus(
      orderId: orderId,
      newStatus: 'picked_up',
      note: note,
    );

    // Optional enrichment only: do not fail pickup confirmation if this column is policy-restricted.
    try {
      await _client
          .from('orders')
          .update({'pickup_point_id': pickupPointId})
          .eq('id', orderId);
    } catch (_) {}
  }

  Future<void> confirmDropoffAtPickupPoint({
    required String orderId,
    required String pickupPointId,
    String? pickupPointName,
  }) async {
    final note = (pickupPointName == null || pickupPointName.trim().isEmpty)
        ? 'Dropped at pickup point'
        : 'Dropped at pickup point: $pickupPointName';

    await updateOrderStatus(
      orderId: orderId,
      newStatus: 'dropped_at_pickup_point',
      note: note,
    );

    // Optional enrichment only: do not fail status transition if this update is restricted.
    try {
      await _client
          .from('orders')
          .update({'pickup_point_id': pickupPointId})
          .eq('id', orderId);
    } catch (_) {}
  }

  Future<void> redirectHomeDeliveryToNearestPickupPoint({
    required String orderId,
  }) async {
    final order = await _client
        .from('orders')
        .select('id, delivery_company_id')
        .eq('id', orderId)
        .maybeSingle();
    if (order == null) {
      throw Exception('Order not found.');
    }

    final companyId = order['delivery_company_id']?.toString();
    final pickupRows = companyId == null || companyId.isEmpty
        ? await _client
              .from('pickup_points')
              .select('id, name')
              .order('name', ascending: true)
              .limit(1)
        : await _client
              .from('pickup_points')
              .select('id, name')
              .eq('company_id', companyId)
              .order('name', ascending: true)
              .limit(1);
    final pickups = List<Map<String, dynamic>>.from(pickupRows);
    if (pickups.isEmpty) {
      throw Exception('No pickup point available for this order.');
    }

    final pickup = pickups.first;
    await confirmDropoffAtPickupPoint(
      orderId: orderId,
      pickupPointId: pickup['id'].toString(),
      pickupPointName: pickup['name']?.toString(),
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

    // Delivery failed means the trip ended for capacity/route purposes.
    if (normalizedNewStatus == 'failed') {
      try {
        final now = DateTime.now().toUtc().toIso8601String();
        await _client
            .from('assignments')
            .update({'completed_at': now})
            .eq('order_id', orderId)
            .eq('driver_id', driverId);

        await _client
            .from('driver_route_stops')
            .update({'completed_at': now, 'updated_at': now})
            .eq('order_id', orderId)
            .eq('driver_id', driverId)
            .isFilter('completed_at', null);
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

    final pickupIds = orders
        .map((order) => order['pickup_point_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

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
    final orderIdToEta = <String, DateTime?>{};
    try {
      final routeStopRows = await _client
          .from('driver_route_stops')
          .select('order_id, stop_type, eta_at, completed_at')
          .inFilter('order_id', orderIds)
          .eq('stop_type', 'dropoff')
          .isFilter('completed_at', null);
      for (final row in List<Map<String, dynamic>>.from(routeStopRows)) {
        final id = row['order_id']?.toString();
        if (id == null || id.isEmpty) continue;
        final eta = _parseDate(row['eta_at']);
        if (eta == null) continue;
        final current = orderIdToEta[id];
        if (current == null || eta.isBefore(current)) {
          orderIdToEta[id] = eta;
        }
      }
    } catch (_) {}

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
      final branch = branchById[order['branch_id']?.toString()];
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
      final dropoffAddress = _firstNonEmpty([
        orderAddress?['dropoff_address_text'],
        orderAddress?['dropoff_address'],
        order['customer_address_text'],
        order['dropoff_address_text'],
        order['dropoff_address'],
        order['delivery_address'],
        order['address'],
      ]);
      final pickupAddress = _firstNonEmpty([
        pickup?['address_text'],
        orderAddress?['pickup_address_text'],
        order['pickup_address_text'],
        order['pickup_address'],
        branch?['address_text'],
      ]);

      result.add(
        DriverDelivery(
          assignmentId: assignment['id'].toString(),
          orderId: orderId,
          companyId: assignment['company_id']?.toString(),
          driverId: assignment['driver_id']?.toString(),
          assignedAt: _parseDate(assignment['assigned_at']),
          completedAt: _parseDate(assignment['completed_at']),
          estimatedArrivalAt: orderIdToEta[orderId],
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
          pickupPointName:
              _firstNonEmpty([
                pickup?['name'],
                order['pickup_name'],
                orderAddress?['pickup_name'],
                branch?['name'],
              ]) ??
              'Pickup point',
          pickupAddress: pickupAddress ?? 'No pickup address',
          pickupLat:
              _toDouble(pickup?['lat']) ??
              _toDouble(orderAddress?['pickup_lat']) ??
              _toDouble(order['pickup_lat']) ??
              _toDouble(branch?['lat']),
          pickupLng:
              _toDouble(pickup?['lng']) ??
              _toDouble(orderAddress?['pickup_lng']) ??
              _toDouble(order['pickup_lng']) ??
              _toDouble(branch?['lng']),
          dropoffAddress: dropoffAddress,
          customerName: customerName ?? 'Unknown customer',
          customerPhone: customerPhone ?? 'No phone',
          customerEmail: customerEmail,
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
}
