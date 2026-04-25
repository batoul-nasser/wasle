import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/domain/delivery_constraints.dart';

class EmailAlreadyRegisteredException implements Exception {
  static const String defaultMessage =
      'This email is already registered. Please log in.';

  final String message;

  const EmailAlreadyRegisteredException([this.message = defaultMessage]);

  @override
  String toString() => message;
}

enum AuthFlowMode {
  login,
  driverSignup,
  companySignup,
  customerSignup,
  merchantSignup,
}

/// Vehicle types supported by the platform.
/// Capacity values are predefined per the routing algorithm spec (PDF §3).
enum VehicleType { motorcycle, car, van }

extension VehicleTypeX on VehicleType {
  String get dbValue {
    switch (this) {
      case VehicleType.motorcycle:
        return 'motorcycle';
      case VehicleType.car:
        return 'car';
      case VehicleType.van:
        return 'van';
    }
  }

  VehicleCapacityProfile get capacityProfile {
    return DeliveryConstraintDefaults.capacityForVehicleType(dbValue);
  }

  String get displayName {
    switch (this) {
      case VehicleType.motorcycle:
        return 'Motorcycle';
      case VehicleType.car:
        return 'Car';
      case VehicleType.van:
        return 'Van';
    }
  }

  /// Max weight in kg
  double get maxWeightKg {
    return capacityProfile.weightKg;
  }

  /// Max volume in cm³
  double get maxVolumeCm3 {
    return capacityProfile.volumeCm3;
  }

  /// Max item count
  int get maxItemCount {
    return capacityProfile.itemCount;
  }

  static VehicleType fromDb(String? value) {
    switch (value?.toLowerCase()) {
      case 'car':
        return VehicleType.car;
      case 'van':
        return VehicleType.van;
      default:
        return VehicleType.motorcycle;
    }
  }
}

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  static const Set<String> _companyAssignableStatuses = {
    'created',
    'pending',
    'assigned',
    'pending_driver_receipt',
    'failed',
    'rescheduled',
    'ready_for_driver_pickup',
    'returned_to_store',
  };

  static const Set<String> _companyTerminalStatuses = {
    'delivered',
    'cancelled',
    'in_transit',
    'picked_up',
    'driver_received_order',
    'returning_to_store',
    'dropped_at_pickup_point',
  };

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendOtp({
    required String email,
    required bool shouldCreateUser,
    String? emailRedirectTo,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (shouldCreateUser) {
      await _assertEmailAvailableForSignup(normalizedEmail);
    }

    await _client.auth.signInWithOtp(
      email: normalizedEmail,
      shouldCreateUser: shouldCreateUser,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    return await _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: token,
      type: OtpType.email,
    );
  }

  Future<bool> isEmailRegistered(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return false;

    final response = await _client.rpc(
      'is_email_registered',
      params: {'lookup_email': normalizedEmail},
    );

    if (response is bool) return response;
    if (response is num) return response != 0;
    if (response is String) {
      return response.toLowerCase() == 'true';
    }
    return false;
  }

  Future<void> _assertEmailAvailableForSignup(String email) async {
    final exists = await isEmailRegistered(email);
    if (!exists) return;

    debugPrint(
      'AUTH [signup_precheck] blocked OTP signup for already-registered email: $email',
    );
    throw const EmailAlreadyRegisteredException();
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getDriverByProfileId(String profileId) async {
    final response = await _client
        .from('drivers')
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getCompanyById(String companyId) async {
    final response = await _client
        .from('delivery_companies')
        .select()
        .eq('id', companyId)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getMerchantByProfileId(String profileId) async {
    final result = await _client
        .from('merchant_users')
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();
    return result;
  }

  Future<String?> getCurrentRole() async {
    final profile = await getCurrentProfile();
    final role = profile?['role']?.toString();
    if (role == null) return null;
    return role.trim().toLowerCase();
  }

  Future<String> resolveInitialRoute() async {
    final user = _client.auth.currentUser;
    if (user == null) return '/welcome';

    final role = await getCurrentRole();

    switch (role) {
      case 'driver':
        final status = await checkDriverStatus();
        if (status == 'approved') return '/driver-dashboard';
        if (status == 'rejected') return '/rejected';
        return '/waiting-approval';
      case 'company_admin':
        return '/company-dashboard';
      case 'customer':
        return '/customer-dashboard';
      case 'merchant':
        return '/merchant-dashboard';
      case 'pickup_point_operator':
        return '/pickup-point-dashboard';
      default:
        return '/welcome';
    }
  }

  Future<String?> checkDriverStatus() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final response = await _client
        .from('drivers')
        .select('verification_status')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (response == null) return null;
    final raw = response['verification_status']?.toString();
    if (raw == null) return null;
    return raw.trim().toLowerCase();
  }

  /// Creates a driver profile with vehicle type + auto-assigned capacity values.
  /// Per PDF §3: vehicle type determines weight, volume, and item-count limits.
  Future<void> createDriverProfile({
    required String userId,
    required String fullName,
    required String phone,
    required String city,
    required VehicleType vehicleType,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'role': 'driver',
    }, onConflict: 'id');

    await _client.from('drivers').upsert({
      'profile_id': userId,
      'verification_status': 'pending',
      'vehicle_type': vehicleType.dbValue,
      'capacity_weight': vehicleType.maxWeightKg,
      'capacity_volume': vehicleType.maxVolumeCm3,
      'capacity_item_count': vehicleType.maxItemCount,
    }, onConflict: 'profile_id');

    final driverRow = await _client
        .from('drivers')
        .select('id')
        .eq('profile_id', userId)
        .maybeSingle();

    if (driverRow != null) {
      final driverId = driverRow['id'] as String;
      await _client.from('driver_locations').upsert({
        'driver_id': driverId,
        'city': city.isEmpty ? null : city,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'driver_id');
    }
  }

  Future<void> createCompanyProfile({
    required String userId,
    required String adminName,
    required String companyName,
    required String location,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': adminName,
      'role': 'company_admin',
    });
    await _client.from('delivery_companies').insert({
      'id': userId,
      'name': companyName,
      'location': location,
    });
  }

  Future<void> createCustomerProfile({
    required String userId,
    required String fullName,
    required String phone,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'role': 'customer',
    });
  }

  Future<void> createMerchantProfile({
    required String userId,
    required String fullName,
    required String phone,
    required String businessName,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'role': 'merchant',
    }, onConflict: 'id');

    final business = await _client
        .from('merchant_businesses')
        .insert({'name': businessName})
        .select('id')
        .single();

    final merchantId = business['id'] as String;

    await _client.from('merchant_users').insert({
      'profile_id': userId,
      'merchant_id': merchantId,
      'role': 'owner',
      'business_name': businessName,
    });
  }

  Future<List<Map<String, dynamic>>> getDeliveryCompanies() async {
    final response = await _client
        .from('delivery_companies')
        .select('id, name')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> sendDriverRequest({
    required String driverProfileId,
    required String companyId,
  }) async {
    final driver = await _client
        .from('drivers')
        .select(
          'vehicle_type, capacity_weight, capacity_volume, capacity_item_count',
        )
        .eq('profile_id', driverProfileId)
        .maybeSingle();

    if (driver == null) {
      throw StateError(
        'Driver profile is incomplete. Please finish onboarding before requesting a delivery company.',
      );
    }

    final missingFields = <String>[
      if (driver['vehicle_type'] == null ||
          driver['vehicle_type'].toString().trim().isEmpty)
        'vehicle_type',
      if (driver['capacity_weight'] == null) 'capacity_weight',
      if (driver['capacity_volume'] == null) 'capacity_volume',
      if (driver['capacity_item_count'] == null) 'capacity_item_count',
    ];

    if (missingFields.isNotEmpty) {
      throw StateError(
        'Driver vehicle capacity is incomplete. Missing: ${missingFields.join(', ')}.',
      );
    }

    await _client.from('driver_company_requests').insert({
      'driver_profile_id': driverProfileId,
      'company_id': companyId,
    });
  }

  Future<List<Map<String, dynamic>>>
  getDriverRequestsForCurrentCompany() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final requests = await _client
        .from('driver_company_requests')
        .select()
        .eq('company_id', user.id)
        .order('created_at', ascending: false);

    List<Map<String, dynamic>> result = [];

    for (final request in requests) {
      final driverProfileId = request['driver_profile_id'];

      final profile = await _client
          .from('profiles')
          .select('id, full_name, phone, role')
          .eq('id', driverProfileId)
          .maybeSingle();

      final driver = await _client
          .from('drivers')
          .select('profile_id, verification_status, vehicle_type')
          .eq('profile_id', driverProfileId)
          .maybeSingle();

      result.add({
        'request_id': request['id'],
        'driver_profile_id': driverProfileId,
        'request_status': request['request_status'],
        'created_at': request['created_at'],
        'full_name': profile?['full_name'],
        'phone': profile?['phone'],
        'role': profile?['role'],
        'verification_status': driver?['verification_status'],
        'vehicle_type': driver?['vehicle_type'],
      });
    }

    return result;
  }

  Future<void> acceptDriverRequest({
    required String requestId,
    required String driverProfileId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client
        .from('driver_company_requests')
        .update({'request_status': 'approved'})
        .eq('id', requestId);

    await _client
        .from('drivers')
        .update({'verification_status': 'approved', 'company_id': user.id})
        .eq('profile_id', driverProfileId);
  }

  Future<void> rejectDriverRequest({
    required String requestId,
    required String driverProfileId,
  }) async {
    await _client
        .from('driver_company_requests')
        .update({'request_status': 'rejected'})
        .eq('id', requestId);

    await _client
        .from('drivers')
        .update({'verification_status': 'rejected'})
        .eq('profile_id', driverProfileId);
  }

  Future<List<Map<String, dynamic>>> getMerchantOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final merchantRow = await _client
        .from('merchant_users')
        .select('merchant_id')
        .eq('profile_id', user.id)
        .maybeSingle();

    if (merchantRow == null) return [];
    final merchantId = merchantRow['merchant_id'] as String;

    final orders = await _client
        .from('orders')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(orders);
  }

  Future<String?> resolveActiveDeliveryCompanyIdForMerchant(
    String merchantId,
  ) async {
    final rows = await _client
        .from('merchant_delivery_companies')
        .select('company_id, is_active, created_at')
        .eq('merchant_id', merchantId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1);

    final mappings = List<Map<String, dynamic>>.from(rows);
    if (mappings.isEmpty) return null;
    return mappings.first['company_id']?.toString();
  }

  Future<void> ensureOrderDeliveryCompanyId({
    required String orderId,
    required String merchantId,
  }) async {
    final companyId = await resolveActiveDeliveryCompanyIdForMerchant(
      merchantId,
    );
    if (companyId == null || companyId.isEmpty) {
      throw Exception('No active delivery company mapping found for merchant');
    }
    await _client
        .from('orders')
        .update({
          'delivery_company_id': companyId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId);
  }

  Future<List<Map<String, dynamic>>> getCompanyAssignmentsOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final companyId = user.id;

    await _backfillLegacyOrderCompanyLinks(companyId);

    final orderRows = await _client
        .from('orders')
        .select(
          'id, merchant_id, branch_id, customer_profile_id, pickup_point_id, '
          'delivery_company_id, status, tracking_code, customer_name, '
          'customer_phone, customer_address_text, created_at, updated_at',
        )
        .eq('delivery_company_id', companyId)
        .order('created_at', ascending: false);

    final orders = List<Map<String, dynamic>>.from(orderRows);
    if (orders.isEmpty) return [];

    final orderIds = orders
        .map((o) => o['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final assignmentRows = await _client
        .from('assignments')
        .select(
          'id, order_id, driver_id, assigned_at, accepted_at, completed_at',
        )
        .eq('company_id', companyId)
        .inFilter('order_id', orderIds)
        .order('assigned_at', ascending: false);

    final assignments = List<Map<String, dynamic>>.from(assignmentRows);
    final assignmentByOrderId = <String, Map<String, dynamic>>{};
    for (final a in assignments) {
      final oid = a['order_id']?.toString();
      if (oid == null || oid.isEmpty) continue;
      assignmentByOrderId.putIfAbsent(oid, () => a);
    }

    Map<String, Map<String, dynamic>> orderAddressByOrderId = {};
    try {
      final addrRows = await _client
          .from('order_addresses')
          .select('*')
          .inFilter('order_id', orderIds);
      orderAddressByOrderId = {
        for (final r in List<Map<String, dynamic>>.from(addrRows))
          if (r['order_id'] != null) r['order_id'].toString(): r,
      };
    } catch (_) {}

    final branchIds = orders
        .map((o) => o['branch_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final pickupIds = orders
        .map((o) => o['pickup_point_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final customerProfileIds = orders
        .map((o) => o['customer_profile_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final driverIds = assignments
        .map((a) => a['driver_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final branches = branchIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('merchant_branches')
                .select('id, merchant_id, name, address_text')
                .inFilter('id', branchIds),
          );
    final branchById = {for (final b in branches) b['id'].toString(): b};

    final allMerchantIds = <String>{
      ...orders
          .map((o) => o['merchant_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
      ...branches
          .map((b) => b['merchant_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
    }.toList();

    final merchants = allMerchantIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('merchant_businesses')
                .select('id, name')
                .inFilter('id', allMerchantIds),
          );
    final merchantById = {for (final m in merchants) m['id'].toString(): m};

    final pickups = pickupIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('pickup_points')
                .select('id, name, address_text')
                .inFilter('id', pickupIds),
          );
    final pickupById = {for (final p in pickups) p['id'].toString(): p};

    final drivers = driverIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('drivers')
                .select('id, profile_id, company_id, vehicle_type')
                .inFilter('id', driverIds)
                .eq('company_id', companyId),
          );
    final driverById = {for (final d in drivers) d['id'].toString(): d};

    final profileIds = <String>{
      ...customerProfileIds,
      ...drivers
          .map((d) => d['profile_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
    }.toList();
    final profiles = profileIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('profiles')
                .select('id, full_name, phone')
                .inFilter('id', profileIds),
          );
    final profileById = {for (final p in profiles) p['id'].toString(): p};

    return orders.map((order) {
      final orderId = order['id']?.toString() ?? '';
      final assignment = assignmentByOrderId[orderId];
      final rawDriverId = assignment?['driver_id']?.toString();
      final driver = rawDriverId == null ? null : driverById[rawDriverId];
      final hasValidDriver =
          rawDriverId != null && rawDriverId.isNotEmpty && driver != null;
      final driverProfileId = driver?['profile_id']?.toString();
      final driverProfile = driverProfileId == null
          ? null
          : profileById[driverProfileId];
      final customerProfileId = order['customer_profile_id']?.toString();
      final customerProfile = customerProfileId == null
          ? null
          : profileById[customerProfileId];
      final branch = branchById[order['branch_id']?.toString()];
      final pickup = pickupById[order['pickup_point_id']?.toString()];
      final merchant =
          merchantById[_firstNonEmpty([
            order['merchant_id'],
            branch?['merchant_id'],
          ])];
      final address = orderAddressByOrderId[orderId];

      return {
        'assignment_id': assignment?['id'],
        'order_id': orderId,
        'tracking_code': _firstNonEmpty([order['tracking_code'], orderId]),
        'status': order['status']?.toString() ?? 'created',
        'pickup_name':
            _firstNonEmpty([pickup?['name'], branch?['name']]) ??
            'Pickup point',
        'pickup_address':
            _firstNonEmpty([
              pickup?['address_text'],
              branch?['address_text'],
            ]) ??
            'No pickup address',
        'merchant_name':
            _firstNonEmpty([merchant?['name']]) ?? 'Unknown merchant',
        'driver_id': hasValidDriver ? rawDriverId : null,
        'driver_name': hasValidDriver
            ? (driverProfile?['full_name']?.toString())
            : null,
        'driver_phone': hasValidDriver
            ? (driverProfile?['phone']?.toString())
            : null,
        'driver_vehicle': hasValidDriver
            ? (driver['vehicle_type']?.toString())
            : null,
        'accepted_at': assignment?['accepted_at'],
        'customer_name':
            _firstNonEmpty([
              customerProfile?['full_name'],
              order['customer_name'],
            ]) ??
            'Unknown customer',
        'customer_phone':
            _firstNonEmpty([
              customerProfile?['phone'],
              order['customer_phone'],
            ]) ??
            'No phone',
        'dropoff_address':
            _firstNonEmpty([
              address?['dropoff_address_text'],
              address?['dropoff_address'],
              order['customer_address_text'],
            ]) ??
            'No dropoff address',
      };
    }).toList();
  }

  Future<void> _backfillLegacyOrderCompanyLinks(String companyId) async {
    try {
      try {
        final assignmentRows = await _client
            .from('assignments')
            .select('order_id')
            .eq('company_id', companyId);
        final orderIds = List<Map<String, dynamic>>.from(assignmentRows)
            .map((r) => r['order_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        if (orderIds.isNotEmpty) {
          await _client
              .from('orders')
              .update({
                'delivery_company_id': companyId,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .inFilter('id', orderIds)
              .isFilter('delivery_company_id', null);
        }
      } catch (_) {}

      final directMappings = List<Map<String, dynamic>>.from(
        await _client
            .from('merchant_delivery_companies')
            .select('merchant_id, company_id')
            .eq('company_id', companyId)
            .eq('is_active', true),
      );
      final merchantIds = directMappings
          .map((r) => r['merchant_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (merchantIds.isEmpty) return;

      final allActiveMappings = List<Map<String, dynamic>>.from(
        await _client
            .from('merchant_delivery_companies')
            .select('merchant_id, company_id')
            .inFilter('merchant_id', merchantIds)
            .eq('is_active', true),
      );
      final companiesByMerchant = <String, Set<String>>{};
      for (final r in allActiveMappings) {
        final mid = r['merchant_id']?.toString();
        final cid = r['company_id']?.toString();
        if (mid == null || mid.isEmpty || cid == null || cid.isEmpty) continue;
        companiesByMerchant.putIfAbsent(mid, () => <String>{}).add(cid);
      }
      final safeMerchantIds = companiesByMerchant.entries
          .where((e) => e.value.length == 1 && e.value.first == companyId)
          .map((e) => e.key)
          .toList();
      if (safeMerchantIds.isEmpty) return;

      await _client
          .from('orders')
          .update({
            'delivery_company_id': companyId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .inFilter('merchant_id', safeMerchantIds)
          .isFilter('delivery_company_id', null);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>>
  getApprovedDriversForCurrentCompany() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final driversRows = List<Map<String, dynamic>>.from(
      await _client
          .from('drivers')
          .select(
            'id, profile_id, company_id, vehicle_type, capacity_weight, capacity_item_count',
          )
          .eq('company_id', user.id)
          .eq('verification_status', 'approved'),
    );
    if (driversRows.isEmpty) return [];

    final profileIds = driversRows
        .map((r) => r['profile_id']?.toString() ?? r['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final profiles = List<Map<String, dynamic>>.from(
      await _client
          .from('profiles')
          .select('id, full_name, phone')
          .inFilter('id', profileIds),
    );
    final profileById = {for (final r in profiles) r['id'].toString(): r};

    return driversRows
        .map((row) {
          final driverId = row['id']?.toString();
          final profileId = row['profile_id']?.toString();
          if (driverId == null ||
              driverId.isEmpty ||
              profileId == null ||
              profileId.isEmpty) {
            return <String, dynamic>{};
          }
          final profile = profileById[profileId];
          return {
            'driver_id': driverId,
            'profile_id': profileId,
            'full_name': profile?['full_name'] ?? 'Driver',
            'phone': profile?['phone'] ?? '-',
            'vehicle_type': row['vehicle_type'] ?? 'motorcycle',
            'capacity_weight': row['capacity_weight'],
            'capacity_item_count': row['capacity_item_count'],
          };
        })
        .where((r) => r.isNotEmpty)
        .toList();
  }

  Future<void> assignOrderToDriver({
    required String orderId,
    required String driverId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final orderRows = await _client
        .from('orders')
        .select('id, status, delivery_company_id')
        .eq('id', orderId)
        .limit(1);
    final orderList = List<Map<String, dynamic>>.from(orderRows);
    if (orderList.isEmpty) throw Exception('Order not found');

    final order = orderList.first;
    final currentStatus = (order['status']?.toString() ?? 'created')
        .toLowerCase();
    final orderCompanyId = order['delivery_company_id']?.toString();

    if (orderCompanyId == null || orderCompanyId.isEmpty) {
      throw Exception('Order has no delivery company assigned');
    }
    if (orderCompanyId != user.id) {
      throw Exception('Order does not belong to your delivery company');
    }

    final driverRows = await _client
        .from('drivers')
        .select('id, company_id, profile_id')
        .eq('id', driverId)
        .limit(1);
    final driverList = List<Map<String, dynamic>>.from(driverRows);
    if (driverList.isEmpty) throw Exception('Selected driver not found');

    final driver = driverList.first;
    final driverCompanyId = driver['company_id']?.toString();
    if (driverCompanyId == null || driverCompanyId != orderCompanyId) {
      throw Exception('Cannot assign order to a driver from another company');
    }

    if (_companyTerminalStatuses.contains(currentStatus)) {
      throw Exception('Cannot assign a closed order');
    }
    if (!_companyAssignableStatuses.contains(currentStatus)) {
      throw Exception('Order already in progress and cannot be reassigned');
    }

    final existingAssignmentRows = await _client
        .from('assignments')
        .select('id, order_id, driver_id')
        .eq('company_id', user.id)
        .eq('order_id', orderId)
        .order('assigned_at', ascending: false)
        .limit(1);
    final existingAssignments = List<Map<String, dynamic>>.from(
      existingAssignmentRows,
    );
    final existingAssignment = existingAssignments.isEmpty
        ? null
        : existingAssignments.first;

    final previousDriverId = existingAssignment?['driver_id']?.toString();
    if (previousDriverId == driverId && currentStatus == 'assigned') return;

    final assignedAt = DateTime.now().toUtc().toIso8601String();
    if (existingAssignment != null) {
      await _client
          .from('assignments')
          .update({
            'driver_id': driverId,
            'assigned_at': assignedAt,
            'accepted_at': null,
            'completed_at': null,
          })
          .eq('id', existingAssignment['id'].toString());
    } else {
      await _client.from('assignments').insert({
        'company_id': user.id,
        'order_id': orderId,
        'driver_id': driverId,
        'assigned_at': assignedAt,
        'accepted_at': null,
        'completed_at': null,
      });
    }

    await _client
        .from('orders')
        .update({
          'status': 'assigned',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .eq('delivery_company_id', orderCompanyId);

    await _client.from('order_events').insert({
      'order_id': orderId,
      'event_type': 'assigned_to_driver',
      'created_by': user.id,
      'note': 'Assigned by delivery company',
    });
  }

  Future<void> unassignOrderFromDriver({required String orderId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final orderRows = await _client
        .from('orders')
        .select('id, status, delivery_company_id')
        .eq('id', orderId)
        .limit(1);
    final orderList = List<Map<String, dynamic>>.from(orderRows);
    if (orderList.isEmpty) throw Exception('Order not found');

    final order = orderList.first;
    final currentStatus = (order['status']?.toString() ?? 'created')
        .toLowerCase();
    final orderCompanyId = order['delivery_company_id']?.toString();

    if (orderCompanyId == null || orderCompanyId.isEmpty) {
      throw Exception('Order has no delivery company assigned');
    }
    if (orderCompanyId != user.id) {
      throw Exception('Order does not belong to your delivery company');
    }
    if (_companyTerminalStatuses.contains(currentStatus)) {
      throw Exception('Cannot unassign a closed or in-progress order');
    }

    final assignmentRows = await _client
        .from('assignments')
        .select('id, driver_id')
        .eq('company_id', user.id)
        .eq('order_id', orderId)
        .order('assigned_at', ascending: false)
        .limit(1);
    final assignments = List<Map<String, dynamic>>.from(assignmentRows);
    if (assignments.isEmpty) return;

    final assignment = assignments.first;
    final hadDriver =
        (assignment['driver_id']?.toString().trim().isNotEmpty ?? false);
    if (!hadDriver) return;

    await _client
        .from('assignments')
        .update({
          'driver_id': null,
          'accepted_at': null,
          'completed_at': null,
          'assigned_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', assignment['id'].toString());

    await _client
        .from('orders')
        .update({
          'status': 'pending',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .eq('delivery_company_id', orderCompanyId);

    await _client.from('order_events').insert({
      'order_id': orderId,
      'event_type': 'note_added',
      'created_by': user.id,
      'note': 'Driver unassigned by delivery company',
    });
  }

  Future<Map<String, dynamic>?> getDriverLocationByDriverId(
    String driverId,
  ) async {
    return await _client
        .from('driver_locations')
        .select()
        .eq('driver_id', driverId)
        .maybeSingle();
  }

  Future<void> upsertDriverLocation({
    required String driverId,
    String? city,
    double? lat,
    double? lng,
  }) async {
    await _client.from('driver_locations').upsert({
      'driver_id': driverId,
      'city': city,
      'lat': lat,
      'lng': lng,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'driver_id');
  }

  User? get currentUser => _client.auth.currentUser;

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != '-') return text;
    }
    return null;
  }
}
