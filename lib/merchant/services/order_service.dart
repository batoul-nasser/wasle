import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import '../models/merchant_notification_model.dart';

final orderService = OrderService._();

class OrderService extends ValueNotifier<List<OrderModel>> {
  OrderService._() : super(const []);

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  RealtimeChannel? _subscription;
  String? _merchantId;
  String? _branchId;

  Future<void> startStream() async {
    await stopStream();
    await _resolveMerchantContext();
    if (_merchantId == null) return;

    await refresh();

    _subscription = _db
        .channel('orders_stream_${_merchantId!}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: _merchantId!,
          ),
          callback: (_) {
            refresh();
          },
        )
        .subscribe();
  }

  Future<void> stopStream() async {
    if (_subscription != null) {
      await _db.removeChannel(_subscription!);
      _subscription = null;
    }
    _merchantId = null;
    _branchId = null;
    value = const [];
  }

  Future<void> refresh() async {
    if (_merchantId == null) {
      await _resolveMerchantContext();
    }
    if (_merchantId == null) return;

    try {
      final rows = await _db
          .from('orders')
          .select()
          .eq('merchant_id', _merchantId!)
          .order('created_at', ascending: false);

      value = (rows as List)
          .map((r) => OrderModel.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[OrderService] refresh error: $e');
    }
  }

  Future<List<Map<String, String>>> loadAvailableDeliveryCompanies() async {
    await _resolveMerchantContext();

    if (_merchantId == null) return const [];

    try {
      final links = await _db
          .from('merchant_delivery_companies')
          .select('company_id, is_active')
          .eq('merchant_id', _merchantId!)
          .eq('is_active', true);

      final ids = (links as List)
          .map((e) => (e as Map<String, dynamic>)['company_id']?.toString())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      if (ids.isEmpty) return const [];

      final companies = await _db
          .from('delivery_companies')
          .select('id, name')
          .inFilter('id', ids)
          .order('name');

      return (companies as List)
          .map((e) => e as Map<String, dynamic>)
          .map(
            (e) => {
              'id': e['id']?.toString() ?? '',
              'name': e['name']?.toString() ?? 'Unnamed Company',
            },
          )
          .where((e) => e['id']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[OrderService] loadAvailableDeliveryCompanies error: $e');
      return const [];
    }
  }

  Future<List<Map<String, String>>> loadAvailablePickupPoints() async {
    await _resolveMerchantContext();

    if (_merchantId == null) return const [];

    try {
      dynamic branchQuery = _db
          .from('pickup_points')
          .select('id, name, address_text')
          .eq('merchant_id', _merchantId!)
          .eq('is_active', true);

      if (_branchId != null) {
        branchQuery = branchQuery.eq('branch_id', _branchId!);
      }

      final branchRows = await branchQuery.order('name');

      if ((branchRows as List).isNotEmpty) {
        return branchRows
            .map((e) => e as Map<String, dynamic>)
            .map(
              (e) => {
                'id': e['id']?.toString() ?? '',
                'name': e['name']?.toString() ?? 'Unnamed Pickup Point',
                'address': e['address_text']?.toString() ?? '',
              },
            )
            .where((e) => e['id']!.isNotEmpty)
            .toList();
      }

      final rows = await _db
          .from('pickup_points')
          .select('id, name, address_text')
          .eq('merchant_id', _merchantId!)
          .eq('is_active', true)
          .order('name');

      return (rows as List)
          .map((e) => e as Map<String, dynamic>)
          .map(
            (e) => {
              'id': e['id']?.toString() ?? '',
              'name': e['name']?.toString() ?? 'Unnamed Pickup Point',
              'address': e['address_text']?.toString() ?? '',
            },
          )
          .where((e) => e['id']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[OrderService] loadAvailablePickupPoints error: $e');
      return const [];
    }
  }


  Future<Map<String, dynamic>> loadMerchantSecuritySnapshot() async {
    await _resolveMerchantContext();

    try {
      final orderRows = _merchantId == null
          ? const []
          : await _db
              .from('orders')
              .select('id, merchant_id, status')
              .eq('merchant_id', _merchantId!)
              .limit(50);

      final merchantIds = (orderRows as List)
          .map((e) => (e as Map<String, dynamic>)['merchant_id']?.toString())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      return {
        'merchantId': _merchantId,
        'branchId': _branchId,
        'ordersCount': orderRows.length,
        'visibleMerchantIds': merchantIds,
      };
    } catch (e) {
      debugPrint('[OrderService] loadMerchantSecuritySnapshot error: $e');
      return {
        'merchantId': _merchantId,
        'branchId': _branchId,
        'ordersCount': value.length,
        'visibleMerchantIds': _merchantId == null ? const <String>[] : <String>[_merchantId!],
      };
    }
  }

  Future<OrderModel> createOrder({
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    required String address,
    required String pickupMethod,
    required double codAmount,
    String? notes,
    String? preferredTimeWindow,
    String? pickupPointId,
    String? deliveryCompanyId,
  }) async {
    await _resolveMerchantContext();

    if (_merchantId == null) {
      throw Exception('Merchant account not found. Please sign in again.');
    }

    final generatedTrackingCode = _generateTrackingCode();

    final draft = OrderModel(
      id: '',
      trackingCode: generatedTrackingCode,
      status: 'created',
      codAmount: codAmount,
      createdAt: '',
      pickupMethod: pickupMethod,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      address: address,
      notes: notes,
      preferredTimeWindow: preferredTimeWindow,
    );

    try {
      final insertMap = draft.toInsertMap(
        merchantId: _merchantId!,
        branchId: _branchId,
        trackingCode: generatedTrackingCode,
        pickupPointId: pickupMethod == 'Pickup Point' ? pickupPointId : null,
      );

      if (deliveryCompanyId != null && deliveryCompanyId.trim().isNotEmpty) {
        insertMap['delivery_company_id'] = deliveryCompanyId.trim();
      }

      final inserted =
          await _db.from('orders').insert(insertMap).select().single();

      final orderId = inserted['id']?.toString();

      if (orderId != null && orderId.isNotEmpty) {
        await _insertOrderCreatedEvent(orderId);

        if (deliveryCompanyId != null && deliveryCompanyId.trim().isNotEmpty) {
          await _insertAssignedToCompanyEvent(orderId);
        }
      }

      final newOrder = OrderModel.fromMap(inserted);
      value = [newOrder, ...value];
      return newOrder;
    } on PostgrestException catch (e) {
      throw Exception('Failed to create order: ${e.message}');
    } catch (_) {
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  Future<void> _insertOrderCreatedEvent(String orderId) async {
    try {
      await _db.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'order_created',
        if (_uid != null) 'created_by': _uid,
      });
    } catch (e) {
      debugPrint('[OrderService] _insertOrderCreatedEvent error: $e');
    }
  }

  Future<void> _insertAssignedToCompanyEvent(String orderId) async {
    try {
      await _db.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'assigned_to_company',
        if (_uid != null) 'created_by': _uid,
      });
    } catch (e) {
      debugPrint('[OrderService] _insertAssignedToCompanyEvent error: $e');
    }
  }

  Future<List<String>> loadTimeline(String orderId) async {
    try {
      final rows = await _db
          .from('order_events')
          .select('event_type, note, metadata, created_at')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      return (rows as List).map((r) {
        final item = r as Map<String, dynamic>;
        final rawType = (item['event_type'] as String?) ?? '';
        final note = item['note'] as String?;
        final createdAt = item['created_at']?.toString();
        final metadata = item['metadata'];

        final label = _eventLabel(rawType, metadata);
        final timeText = _formatTimestamp(createdAt);

        if (note != null && note.trim().isNotEmpty && timeText != null) {
          return '$label — $note · $timeText';
        }

        if (note != null && note.trim().isNotEmpty) {
          return '$label — $note';
        }

        if (timeText != null) {
          return '$label · $timeText';
        }

        return label;
      }).toList();
    } catch (_) {
      return ['Order created'];
    }
  }

  Future<Map<String, String?>> loadAssignmentDetails(String orderId) async {
    String? assignedCompany;
    String? driverName;
    String? driverPhone;
    String? assignmentTime;
    String? expectedPickupTime;

    try {
      final orderRow = await _db
          .from('orders')
          .select('delivery_company_id')
          .eq('id', orderId)
          .maybeSingle();

      final deliveryCompanyId = orderRow?['delivery_company_id']?.toString();

      if (deliveryCompanyId != null && deliveryCompanyId.isNotEmpty) {
        final companyRow = await _db
            .from('delivery_companies')
            .select('name')
            .eq('id', deliveryCompanyId)
            .maybeSingle();

        assignedCompany = companyRow?['name']?.toString();
      }

      final eventRows = await _db
          .from('order_events')
          .select('event_type, created_by, created_at, note, metadata')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      final events = List<Map<String, dynamic>>.from(eventRows as List);

      Map<String, dynamic>? assignedCompanyEvent;
      Map<String, dynamic>? assignedDriverEvent;

      for (final e in events) {
        final type = e['event_type']?.toString();
        if (type == 'assigned_to_company' && assignedCompanyEvent == null) {
          assignedCompanyEvent = e;
        }
        if (type == 'assigned_to_driver' && assignedDriverEvent == null) {
          assignedDriverEvent = e;
        }
      }

      final assignmentSource = assignedDriverEvent ?? assignedCompanyEvent;
      assignmentTime = _formatTimestamp(
        assignmentSource?['created_at']?.toString(),
      );

      final reversed = events.reversed.toList();

      String? driverProfileId;
      for (final e in reversed) {
        final type = e['event_type']?.toString() ?? '';
        final createdBy = e['created_by']?.toString();

        if (createdBy == null || createdBy.isEmpty) continue;

        final isDriverAction = type == 'picked_up' ||
            type == 'in_transit' ||
            type == 'delivered' ||
            type == 'failed' ||
            type == 'dropped_at_pickup_point';

        if (!isDriverAction) continue;

        final driverRow = await _db
            .from('drivers')
            .select('profile_id, company_id, verification_status')
            .eq('profile_id', createdBy)
            .maybeSingle();

        if (driverRow != null) {
          driverProfileId = createdBy;
          break;
        }
      }

      if (driverProfileId != null) {
        final profileRow = await _db
            .from('profiles')
            .select('full_name, phone')
            .eq('id', driverProfileId)
            .maybeSingle();

        driverName = profileRow?['full_name']?.toString();
        driverPhone = profileRow?['phone']?.toString();
      }

      expectedPickupTime = null;
    } catch (e) {
      debugPrint('[OrderService] loadAssignmentDetails error: $e');
    }


    return {
      'assignedCompany': assignedCompany,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'assignmentTime': assignmentTime,
      'expectedPickupTime': expectedPickupTime,
    };
  }

  Future<Map<String, String?>> loadExceptionDetails(String orderId) async {
    try {
      final rows = await _db
          .from('order_events')
          .select('event_type, note, metadata, created_at')
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      return _buildIssueSummaryFromRows(rows as List);
    } catch (e) {
      debugPrint('[OrderService] loadExceptionDetails error: $e');
      return {
        'failedReason': null,
        'resolution': null,
        'cancellationReason': null,
        'occurredAt': null,
        'returnState': null,
        'rescheduledFor': null,
      };
    }
  }

  Future<Map<String, Map<String, String?>>> loadIssueSummaries({
    Iterable<String>? orderIds,
  }) async {
    await _resolveMerchantContext();

    if (_merchantId == null) return const {};

    try {
      final ids = orderIds
              ?.map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList() ??
          value
              .where((o) => _exceptionStatuses.contains(o.status))
              .map((o) => o.id)
              .where((e) => e.trim().isNotEmpty)
              .toSet()
              .toList();

      if (ids.isEmpty) return const {};

      final rows = await _db
          .from('order_events')
          .select('order_id, event_type, note, metadata, created_at')
          .inFilter('order_id', ids)
          .order('created_at', ascending: false);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final raw in rows as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        final orderId = item['order_id']?.toString();
        if (orderId == null || orderId.isEmpty) continue;
        grouped.putIfAbsent(orderId, () => <Map<String, dynamic>>[]).add(item);
      }

      final result = <String, Map<String, String?>>{};
      for (final id in ids) {
        result[id] = _buildIssueSummaryFromRows(grouped[id] ?? const []);
      }
      return result;
    } catch (e) {
      debugPrint('[OrderService] loadIssueSummaries error: $e');
      return const {};
    }
  }

  Future<void> requestCancellation({
    required String orderId,
    required String currentStatus,
    required String reason,
  }) async {
    final normalized = currentStatus.trim().toLowerCase();
    if (!(normalized == 'created' || normalized == 'assigned')) {
      throw Exception('Cancellation is only allowed before pickup.');
    }

    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw Exception('Please enter a cancellation reason.');
    }

    try {
      await _db.from('orders').update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      await _db.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'cancelled',
        'note': cleanReason,
        if (_uid != null) 'created_by': _uid,
        'metadata': {
          'requested_by': 'merchant',
          'previous_status': normalized,
        },
      });

      await refresh();
    } on PostgrestException catch (e) {
      throw Exception('Failed to request cancellation: ${e.message}');
    } catch (e) {
      throw Exception('Failed to request cancellation. Please try again.');
    }
  }


  Future<List<MerchantNotificationModel>> loadRecentNotifications({
    int limit = 20,
  }) async {
    await _resolveMerchantContext();

    if (_merchantId == null) return const [];

    try {
      final orderRows = await _db
          .from('orders')
          .select('id, tracking_code, status')
          .eq('merchant_id', _merchantId!)
          .order('created_at', ascending: false)
          .limit(100);

      final orderMaps = (orderRows as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      if (orderMaps.isEmpty) return const [];

      final orderIds = orderMaps
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();

      if (orderIds.isEmpty) return const [];

      final orderInfo = <String, Map<String, dynamic>>{
        for (final row in orderMaps)
          if ((row['id']?.toString() ?? '').isNotEmpty)
            row['id'].toString(): row,
      };

      final eventRows = await _db
          .from('order_events')
          .select('order_id, event_type, note, metadata, created_at')
          .inFilter('order_id', orderIds)
          .order('created_at', ascending: false)
          .limit(limit);

      return (eventRows as List)
          .map((e) => e as Map<String, dynamic>)
          .map((event) {
            final orderId = event['order_id']?.toString() ?? '';
            final order = orderInfo[orderId] ?? const <String, dynamic>{};
            final trackingCode = order['tracking_code']?.toString() ?? 'Unknown';
            final status = order['status']?.toString();
            final rawType = event['event_type']?.toString() ?? '';
            final metadata = event['metadata'];
            final note = event['note']?.toString().trim();
            final createdAt = event['created_at']?.toString();

            final title = _eventLabel(rawType, metadata);
            final body = _notificationBody(
              trackingCode: trackingCode,
              rawType: rawType,
              note: note,
              metadata: metadata,
            );

            return MerchantNotificationModel(
              orderId: orderId,
              trackingCode: trackingCode,
              eventType: rawType,
              title: title,
              body: body,
              createdAt: _formatTimestamp(createdAt),
              status: status,
            );
          })
          .toList();
    } catch (e) {
      debugPrint('[OrderService] loadRecentNotifications error: $e');
      return const [];
    }
  }

  Future<OrderModel?> getOrderWithTimeline(String orderId) async {
    try {
      final row =
          await _db.from('orders').select().eq('id', orderId).maybeSingle();

      if (row == null) return null;

      final order = OrderModel.fromMap(row);
      final timeline = await loadTimeline(orderId);
      return order.withTimeline(timeline);
    } catch (_) {
      return null;
    }
  }

  int get totalOrders => value.length;

  int get activeOrders => value
      .where((o) => o.status != 'delivered' && !_exceptionStatuses.contains(o.status))
      .length;

  int get deliveredOrders => value.where((o) => o.status == 'delivered').length;

  int get failedOrders => value.where((o) => _exceptionStatuses.contains(o.status)).length;

  double get pendingCod => value
      .where((o) => o.status != 'delivered' && o.codAmount > 0)
      .fold(0.0, (sum, o) => sum + o.codAmount);

  Future<void> _resolveMerchantContext() async {
    if (_merchantId != null && _branchId != null) return;

    final uid = _uid;
    if (uid == null) return;

    try {
      final membership = await _db
          .from('merchant_users')
          .select('merchant_id')
          .eq('profile_id', uid)
          .maybeSingle();

      if (membership != null) {
        _merchantId = membership['merchant_id']?.toString();
      }

      if (_merchantId != null && _branchId == null) {
        final branch = await _db
            .from('merchant_branches')
            .select('id')
            .eq('merchant_id', _merchantId!)
            .maybeSingle();

        if (branch != null) {
          _branchId = branch['id']?.toString();
        }
      }
    } catch (e) {
      debugPrint('[OrderService] _resolveMerchantContext error: $e');
    }
  }

  String _generateTrackingCode() {
    final now = DateTime.now();
    final random = Random();

    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final suffix = (1000 + random.nextInt(9000)).toString();

    return 'WAS-M-$year$month$day$hour$minute$second$suffix';
  }

  String _eventLabel(String rawType, [dynamic metadata]) {
    switch (rawType) {
      case 'order_created':
        return 'Order created';
      case 'assigned_to_company':
        return 'Assigned to company';
      case 'assigned_to_driver':
        return 'Assigned to driver';
      case 'picked_up':
        return 'Picked up';
      case 'in_transit':
        return 'In transit';
      case 'delivered':
        return 'Delivered';
      case 'failed':
      case 'delivery_failed':
        return 'Delivery failed';
      case 'cancelled':
        return 'Cancelled by merchant';
      case 'customer_not_available':
        return 'Customer not available';
      case 'rescheduled':
        return 'Rescheduled';
      case 'dropped_at_pickup_point':
        return 'Dropped at pickup point';
      case 'returning_to_store':
        return 'Return to store started';
      case 'returned_to_store':
        return 'Returned to store';
      default:
        if (rawType.trim().isEmpty) return 'Order update';
        final clean = rawType.replaceAll('_', ' ');
        return '${clean[0].toUpperCase()}${clean.substring(1)}';
    }
  }


  
  static const Set<String> _exceptionStatuses = {
    'failed',
    'cancelled',
    'returning',
    'returned_to_store',
  };

  Map<String, String?> _buildIssueSummaryFromRows(List rows) {
    String? failedReason;
    String? resolution;
    String? cancellationReason;
    String? occurredAt;
    String? returnState;
    String? rescheduledFor;

    for (final raw in rows) {
      final item = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      final type = _normalizeEventType(item['event_type']?.toString());
      final note = item['note']?.toString().trim();
      final metadata = item['metadata'] is Map
          ? Map<String, dynamic>.from(item['metadata'] as Map)
          : <String, dynamic>{};
      final createdAt = _formatTimestamp(item['created_at']?.toString());

      if (type == 'cancelled' && cancellationReason == null) {
        cancellationReason = note;
        occurredAt ??= createdAt;
      }

      if ((type == 'failed' || type == 'delivery_failed') && failedReason == null) {
        failedReason = _firstNonEmpty([
          metadata['failure_reason'],
          metadata['failed_reason'],
          metadata['reason'],
          note,
        ]);
        resolution = _normalizeResolution(_firstNonEmpty([
          metadata['resolution'],
          metadata['selected_resolution'],
          metadata['outcome'],
        ]));
        rescheduledFor ??= _firstNonEmpty([
          metadata['rescheduled_for'],
          metadata['scheduled_for'],
          metadata['new_delivery_time'],
        ]);
        occurredAt ??= createdAt;
      }

      if (type == 'customer_not_available' && failedReason == null) {
        failedReason = 'Customer not available';
        resolution = _normalizeResolution(_firstNonEmpty([
          metadata['resolution'],
          metadata['selected_resolution'],
          note,
        ]));
        rescheduledFor ??= _firstNonEmpty([
          metadata['rescheduled_for'],
          metadata['scheduled_for'],
          metadata['new_delivery_time'],
        ]);
        occurredAt ??= createdAt;
      }

      if (type == 'dropped_at_pickup_point') {
        failedReason ??= _firstNonEmpty([
          metadata['failure_reason'],
          metadata['failed_reason'],
          'Customer not available',
        ]);
        resolution ??= 'Pickup point drop';
        occurredAt ??= createdAt;
      }

      if (type == 'rescheduled') {
        failedReason ??= _firstNonEmpty([
          metadata['failure_reason'],
          metadata['failed_reason'],
          'Customer not available',
        ]);
        resolution ??= 'Rescheduled';
        rescheduledFor ??= _firstNonEmpty([
          metadata['rescheduled_for'],
          metadata['scheduled_for'],
          metadata['new_delivery_time'],
          note,
        ]);
        occurredAt ??= createdAt;
      }

      if (type == 'returning' || type == 'returning_to_store') {
        failedReason ??= _firstNonEmpty([
          metadata['failure_reason'],
          metadata['failed_reason'],
          'Customer not available',
        ]);
        resolution ??= 'Return to store';
        returnState = 'Returning to store';
        occurredAt ??= createdAt;
      }

      if (type == 'returned_to_store') {
        failedReason ??= _firstNonEmpty([
          metadata['failure_reason'],
          metadata['failed_reason'],
          'Customer not available',
        ]);
        resolution ??= 'Return to store';
        returnState = 'Returned to store';
        occurredAt ??= createdAt;
      }
    }

    final resolutionText = _mergeResolutionDetails(
      resolution: resolution,
      returnState: returnState,
      rescheduledFor: rescheduledFor,
    );

    return {
      'failedReason': _humanizeReason(failedReason),
      'resolution': resolutionText,
      'cancellationReason': cancellationReason,
      'occurredAt': occurredAt,
      'returnState': returnState,
      'rescheduledFor': rescheduledFor,
    };
  }

  String _normalizeEventType(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    switch (value) {
      case 'returning_to_store':
        return 'returning_to_store';
      case 'returning':
        return 'returning';
      default:
        return value;
    }
  }

  String? _normalizeResolution(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    switch (value.toLowerCase()) {
      case 'drop_at_pickup_point':
      case 'pickup_point_drop':
        return 'Pickup point drop';
      case 'return_to_store':
        return 'Return to store';
      case 'rescheduled':
        return 'Rescheduled';
      default:
        return value.replaceAll('_', ' ');
    }
  }

  String _mergeResolutionDetails({
    String? resolution,
    String? returnState,
    String? rescheduledFor,
  }) {
    final parts = <String>[];
    final cleanResolution = resolution?.trim();
    if (cleanResolution != null && cleanResolution.isNotEmpty) {
      parts.add(cleanResolution);
    }
    final cleanReturnState = returnState?.trim();
    if (cleanReturnState != null &&
        cleanReturnState.isNotEmpty &&
        cleanReturnState != cleanResolution) {
      parts.add(cleanReturnState);
    }
    final cleanRescheduledFor = rescheduledFor?.trim();
    if (cleanRescheduledFor != null && cleanRescheduledFor.isNotEmpty) {
      parts.add('Scheduled for $cleanRescheduledFor');
    }
    return parts.join(' · ');
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  String? _humanizeReason(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    switch (value.toLowerCase()) {
      case 'customer_not_available':
      case 'customer_not_home':
        return 'Customer not available';
      case 'merchant_cancelled':
        return 'Cancelled by merchant';
      default:
        return value.replaceAll('_', ' ');
    }
  }

String _notificationBody({
    required String trackingCode,
    required String rawType,
    String? note,
    dynamic metadata,
  }) {
    final cleanNote = note?.trim();
    if (cleanNote != null && cleanNote.isNotEmpty) {
      return 'Order $trackingCode — $cleanNote';
    }

    if (metadata is Map) {
      final failureReason = _firstNonEmpty([
        metadata['failure_reason'],
        metadata['failed_reason'],
        metadata['reason'],
      ]);
      final resolution = _normalizeResolution(_firstNonEmpty([metadata['resolution'], metadata['selected_resolution'], metadata['outcome']]));
      final previousStatus = metadata['previous_status']?.toString();

      if (failureReason != null && failureReason.isNotEmpty) {
        if (resolution != null && resolution.isNotEmpty) {
          return 'Order $trackingCode — ${_humanizeReason(failureReason) ?? failureReason}, resolution: $resolution';
        }
        return 'Order $trackingCode — ${_humanizeReason(failureReason) ?? failureReason}';
      }

      if (resolution != null && resolution.isNotEmpty) {
        return 'Order $trackingCode — resolution: $resolution';
      }

      if (rawType == 'cancelled' &&
          previousStatus != null &&
          previousStatus.isNotEmpty) {
        return 'Order $trackingCode — cancelled from $previousStatus state';
      }
    }

    return 'Order $trackingCode has a new update.';
  }

  String? _formatTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return null;

    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }
}