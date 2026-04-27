import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthFlowMode {
  login,
  driverSignup,
  companySignup,
  customerSignup,
  merchantSignup,
  pickupPointSignup,
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
    Map<String, dynamic>? data,
  }) async {
    if (shouldCreateUser && _client.auth.currentUser != null) {
      await _client.auth.signOut();
    }

    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: shouldCreateUser,
      emailRedirectTo: emailRedirectTo,
      data: data,
    );
  }

  Future<void> resendSignupOtp({required String email}) async {
    await _resendEmailOtp(
      email: email,
      preferredType: OtpType.email,
      fallbackType: OtpType.signup,
    );
  }

  Future<void> resendLoginOtp({required String email}) async {
    await _resendEmailOtp(
      email: email,
      preferredType: OtpType.email,
      fallbackType: OtpType.signup,
    );
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    required AuthFlowMode mode,
  }) async {
    final preferredType =
        mode == AuthFlowMode.login ? OtpType.email : OtpType.signup;

    return await _verifyEmailOtp(
      email: email,
      token: token,
      preferredType: preferredType,
      fallbackType: preferredType == OtpType.email
          ? OtpType.signup
          : OtpType.email,
    );
  }

  Future<AuthResponse> _verifyEmailOtp({
    required String email,
    required String token,
    required OtpType preferredType,
    OtpType? fallbackType,
  }) async {
    AuthException? firstError;

    try {
      return await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: preferredType,
      );
    } on AuthException catch (error) {
      firstError = error;
    }

    if (fallbackType == null || fallbackType == preferredType) {
      throw firstError!;
    }

    try {
      return await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: fallbackType,
      );
    } on AuthException {
      throw firstError!;
    }
  }

  Future<void> _resendEmailOtp({
    required String email,
    required OtpType preferredType,
    OtpType? fallbackType,
  }) async {
    AuthException? firstError;

    try {
      await _client.auth.resend(type: preferredType, email: email);
      return;
    } on AuthException catch (error) {
      firstError = error;
    }

    if (fallbackType == null || fallbackType == preferredType) {
      throw firstError!;
    }

    try {
      await _client.auth.resend(type: fallbackType, email: email);
    } on AuthException {
      throw firstError!;
    }
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

  Future<Map<String, dynamic>?> getMyPickupPoint() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    return await _client
        .from('pickup_points')
        .select()
        .eq('owner_profile_id', user.id)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> getMyPickupPointApplication() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    return await _client
        .from('pickup_point_applications')
        .select()
        .eq('user_id', user.id)
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getPickupPointApplications({
    String status = 'pending',
  }) async {
    final rows = await _client
        .from('pickup_point_applications')
        .select()
        .eq('verification_status', status)
        .order('submitted_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> getCustomerRecentPickupPoints({
    int limit = 10,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final orderRows = await _client
        .from('orders')
        .select('pickup_point_id, created_at')
        .eq('customer_profile_id', user.id)
        .not('pickup_point_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit * 3);

    final orders = List<Map<String, dynamic>>.from(orderRows);
    if (orders.isEmpty) return [];

    final pickupIds = <String>[];
    for (final order in orders) {
      final pickupId = order['pickup_point_id']?.toString();
      if (pickupId == null ||
          pickupId.isEmpty ||
          pickupIds.contains(pickupId)) {
        continue;
      }
      pickupIds.add(pickupId);
      if (pickupIds.length >= limit) break;
    }

    if (pickupIds.isEmpty) return [];

    final pickupRows = await _client
        .from('pickup_points')
        .select('id, name, address_text, city, area, phone')
        .inFilter('id', pickupIds);

    final pickupById = {
      for (final row in List<Map<String, dynamic>>.from(pickupRows))
        if (row['id'] != null) row['id'].toString(): row,
    };

    return pickupIds
        .map((id) => pickupById[id])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, Map<String, dynamic>>> getPickupPointRatingSummaries(
    List<String> pickupPointIds,
  ) async {
    if (pickupPointIds.isEmpty) return {};

    final rows = await _client
        .from('pickup_point_reviews')
        .select('pickup_point_id, rating')
        .inFilter('pickup_point_id', pickupPointIds);

    final summaries = <String, Map<String, dynamic>>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final pickupPointId = row['pickup_point_id']?.toString();
      final rating = (row['rating'] as num?)?.toDouble();
      if (pickupPointId == null || pickupPointId.isEmpty || rating == null) {
        continue;
      }

      final summary = summaries.putIfAbsent(
        pickupPointId,
        () => {'count': 0, 'total': 0.0},
      );
      summary['count'] = (summary['count'] as int) + 1;
      summary['total'] = (summary['total'] as double) + rating;
    }

    for (final entry in summaries.entries) {
      final count = entry.value['count'] as int;
      final total = entry.value['total'] as double;
      entry.value['average'] = count == 0 ? 0.0 : total / count;
    }

    return summaries;
  }

  Future<List<Map<String, dynamic>>> getPickupPointReviews(
    String pickupPointId,
  ) async {
    if (pickupPointId.trim().isEmpty) return [];

    final rows = await _client
        .from('pickup_point_reviews')
        .select(
          'id, pickup_point_id, customer_profile_id, rating, comment, created_at',
        )
        .eq('pickup_point_id', pickupPointId)
        .order('created_at', ascending: false);

    final reviews = List<Map<String, dynamic>>.from(rows);
    if (reviews.isEmpty) return [];

    final customerIds = reviews
        .map((review) => review['customer_profile_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final profiles = customerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', customerIds),
          );

    final profileById = {
      for (final profile in profiles)
        if (profile['id'] != null) profile['id'].toString(): profile,
    };

    return reviews.map((review) {
      final profile = profileById[review['customer_profile_id']?.toString()];
      return {
        ...review,
        'customer_name': profile?['full_name']?.toString() ?? 'Customer',
      };
    }).toList();
  }

  Future<void> submitPickupPointReview({
    required String pickupPointId,
    required int rating,
    required String comment,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }
    if (pickupPointId.trim().isEmpty) {
      throw Exception('Pickup point is missing.');
    }
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5.');
    }

    final orders = await _client
        .from('orders')
        .select('id')
        .eq('customer_profile_id', user.id)
        .eq('pickup_point_id', pickupPointId)
        .limit(1);

    if ((orders as List).isEmpty) {
      throw Exception('You can only review pickup points you used before.');
    }

    await _client.from('pickup_point_reviews').upsert({
      'pickup_point_id': pickupPointId,
      'customer_profile_id': user.id,
      'rating': rating,
      'comment': comment.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'pickup_point_id,customer_profile_id');
  }

  Future<void> approvePickupPointApplication({
    required String applicationId,
  }) async {
    final admin = _client.auth.currentUser;
    if (admin == null) {
      throw Exception('User not logged in');
    }

    final application = await _client
        .from('pickup_point_applications')
        .select()
        .eq('id', applicationId)
        .maybeSingle();

    if (application == null) {
      throw Exception('Pickup point application not found');
    }

    final applicantId = application['user_id']?.toString();
    if (applicantId == null || applicantId.isEmpty) {
      throw Exception('Pickup point applicant is missing');
    }

    final pickupPayload = <String, dynamic>{
      'owner_profile_id': applicantId,
      'created_by': admin.id,
      'name': application['pickup_point_name'],
      'owner_name': application['owner_name'],
      'phone': application['phone'],
      'email': application['email'],
      'address_text': application['address_text'],
      'city': application['city'],
      'area': application['area'],
      'opens_at': application['opens_at'],
      'closes_at': application['closes_at'],
      'opening_hours': _buildOpeningHours(
        opensAt: application['opens_at']?.toString(),
        closesAt: application['closes_at']?.toString(),
      ),
      'working_days': application['working_days'],
      'preferred_payment_method': application['preferred_payment_method'],
      'payment_handling_method': application['payment_handling_method'],
      'max_orders_per_day': application['max_orders_per_day'],
      'image_url': application['shop_image_url'],
      'status': 'active',
      'is_active': true,
    };

    final existingPickupPoint = await _client
        .from('pickup_points')
        .select('id')
        .eq('owner_profile_id', applicantId)
        .maybeSingle();

    String pickupPointId;
    if (existingPickupPoint != null) {
      pickupPointId = existingPickupPoint['id'].toString();
      await _client
          .from('pickup_points')
          .update(pickupPayload)
          .eq('id', pickupPointId);
    } else {
      final created = await _client
          .from('pickup_points')
          .insert(pickupPayload)
          .select('id')
          .single();
      pickupPointId = created['id'].toString();
    }

    await _client.from('profiles').upsert({
      'id': applicantId,
      'full_name': application['owner_name'],
      'phone': application['phone'],
      'role': 'pickup_point',
    }, onConflict: 'id');

    try {
      final existingOperator = await _client
          .from('pickup_point_operators')
          .select('pickup_point_id')
          .eq('profile_id', applicantId)
          .eq('pickup_point_id', pickupPointId)
          .maybeSingle();

      if (existingOperator == null) {
        await _client.from('pickup_point_operators').insert({
          'profile_id': applicantId,
          'pickup_point_id': pickupPointId,
        });
      }
    } catch (_) {
      // Fallback to owner_profile_id lookup if operator mapping table is unavailable.
    }

    await _client
        .from('pickup_point_applications')
        .update({'verification_status': 'approved'})
        .eq('id', applicationId);
  }

  Future<void> rejectPickupPointApplication({
    required String applicationId,
  }) async {
    await _client
        .from('pickup_point_applications')
        .update({'verification_status': 'rejected'})
        .eq('id', applicationId);
  }

  String _buildOpeningHours({
    required String? opensAt,
    required String? closesAt,
  }) {
    final open = opensAt?.trim() ?? '';
    final close = closesAt?.trim() ?? '';
    if (open.isEmpty && close.isEmpty) return '';
    if (open.isEmpty) return close;
    if (close.isEmpty) return open;
    return '$open - $close';
  }

  Future<String?> getCurrentRole() async {
    final profile = await getCurrentProfile();
    final role = profile?['role']?.toString();
    if (role == null) return null;
    return role.trim().toLowerCase();
  }

  Future<String> resolveInitialRoute() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return '/welcome';
    }

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

      case 'pickup_point_applicant':
        final application = await getMyPickupPointApplication();
        final status = application?['verification_status']
            ?.toString()
            .trim()
            .toLowerCase();

        if (status == 'approved') {
          return '/pickup-dashboard';
        }
        if (status == 'rejected') {
          return '/pickup-application-rejected';
        }
        return '/pickup-application-pending';

      case 'pickup_point_operator':
        return '/pickup-point-dashboard';

      case 'platform_admin':
        return '/admin-dashboard';

      case 'agent':
        return '/agent-dashboard';

      case 'pickup_point':
        return '/pickup-dashboard';

      default:
        return '/welcome';
    }
  }

  Future<String?> checkDriverStatus() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    Map<String, dynamic>? response;
    try {
      response = await _client
          .from('drivers')
          .select('verification_status')
          .eq('profile_id', user.id)
          .maybeSingle();
    } catch (_) {
      response = null;
    }

    response ??= await _client
        .from('drivers')
        .select('verification_status')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    final raw = response['verification_status']?.toString();
    if (raw == null) return null;
    return raw.trim().toLowerCase();
  }

<<<<<<< Updated upstream
=======
  Future<String?> getLatestDriverRequestStatus() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final request = await _client
        .from('driver_company_requests')
        .select('request_status')
        .eq('driver_profile_id', user.id)
        .order('updated_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final raw = request?['request_status']?.toString();
    if (raw == null) return null;
    return raw.trim().toLowerCase();
  }

  Future<Map<String, dynamic>?> getLatestDriverRequestSummary() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final request = await _client
        .from('driver_company_requests')
        .select('id, company_id, request_status, created_at')
        .eq('driver_profile_id', user.id)
        .order('updated_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (request == null) return null;

    Map<String, dynamic>? company;
    final companyId = request['company_id']?.toString();
    if (companyId != null && companyId.isNotEmpty) {
      company = await getCompanyById(companyId);
    }

    return {
      'id': request['id'],
      'company_id': companyId,
      'request_status': request['request_status']?.toString(),
      'created_at': request['created_at'],
      'company_name': company?['name']?.toString(),
    };
  }

  Future<void> syncDriverCompanyLinkFromApprovedRequest() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final driver = await getDriverByProfileId(user.id);
    final companyId = driver?['company_id']?.toString();
    final status = driver?['verification_status']?.toString().trim().toLowerCase();

    // Already linked and approved, nothing to repair.
    if (companyId != null &&
        companyId.isNotEmpty &&
        status == 'approved') {
      return;
    }

    final latestRequest = await _client
        .from('driver_company_requests')
        .select('company_id, request_status')
        .eq('driver_profile_id', user.id)
        .order('updated_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final requestStatus = latestRequest?['request_status']
        ?.toString()
        .trim()
        .toLowerCase();
    final requestCompanyId = latestRequest?['company_id']?.toString();

    if (requestStatus != 'approved' ||
        requestCompanyId == null ||
        requestCompanyId.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _updateDriverRowsWithSchemaFallback(
      profileId: user.id,
      values: {
        'verification_status': 'approved',
        'company_id': requestCompanyId,
        'updated_at': now,
      },
    );
    await _updateDriverRowsWithSchemaFallback(
      driverId: user.id,
      values: {
        'verification_status': 'approved',
        'company_id': requestCompanyId,
        'updated_at': now,
      },
    );
  }

>>>>>>> Stashed changes
  Future<String?> uploadPickupPointStorageAreaImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = 'storage/$fileName';

    await _client.storage
        .from('pickup-point-storage')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('pickup-point-storage').getPublicUrl(path);
  }

  Future<String?> uploadPickupPointShelvesImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = 'shelves/$fileName';

    await _client.storage
        .from('pickup-point-shelves')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('pickup-point-shelves').getPublicUrl(path);
  }

  Future<String?> uploadPickupPointShopImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = 'shops/$fileName';

    await _client.storage
        .from('pickup-point-shops')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('pickup-point-shops').getPublicUrl(path);
  }

  Future<String?> uploadPickupPointIdImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = 'ids/$fileName';

    await _client.storage
        .from('pickup-point-ids')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('pickup-point-ids').getPublicUrl(path);
  }

  Future<void> createDriverProfile({
    required String userId,
    required String fullName,
    required String phone,
    required String city,
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
    required String branchName,
    required String addressText,
    required double branchLat,
    required double branchLng,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'role': 'merchant',
    }, onConflict: 'id');

    final existingMerchantUser = await _client
        .from('merchant_users')
        .select('merchant_id')
        .eq('profile_id', userId)
        .maybeSingle();

    String merchantId;

    if (existingMerchantUser != null &&
        existingMerchantUser['merchant_id'] != null) {
      merchantId = existingMerchantUser['merchant_id'].toString();
    } else {
      final business = await _client
          .from('merchant_businesses')
          .insert({'name': businessName})
          .select('id')
          .single();

      merchantId = business['id'] as String;

      await _client.from('merchant_users').insert({
        'profile_id': userId,
        'merchant_id': merchantId,
        'role': 'owner',
        'business_name': businessName,
      });
    }

    final existingBranch = await _client
        .from('merchant_branches')
        .select('id')
        .eq('merchant_id', merchantId)
        .limit(1)
        .maybeSingle();

    if (existingBranch == null) {
      await _client.from('merchant_branches').insert({
        'merchant_id': merchantId,
        'created_by': userId,
        'name': branchName,
        'address_text': addressText,
        'lat': branchLat,
        'lng': branchLng,
        'is_active': true,
      });
    } else {
      await _client
          .from('merchant_branches')
          .update({
            'name': branchName,
            'address_text': addressText,
            'lat': branchLat,
            'lng': branchLng,
            'is_active': true,
          })
          .eq('id', existingBranch['id'].toString());
    }
  }

  Future<void> createPickupPointApplication({
    required String userId,
    required String ownerName,
    required String phone,
    required String email,
    required String pickupPointName,
    required String addressText,
    required String confirmAddressText,
    required String city,
    required String area,
    int? maxOrdersPerDay,
    List<String>? workingDays,
    required String opensAt,
    required String closesAt,
    String commissionType = 'custom',
    double? commissionValue,
    String? commissionPlan,
    required String preferredPaymentMethod,
    String? paymentHandlingMethod,
    String? storageTier,
    double? estimatedStorageSqm,
    bool hasShelves = false,
    int? estimatedCapacityUnits,
    required String shopImageUrl,
    required String idImageUrl,
    required String storageAreaImageUrl,
    required String shelvesImageUrl,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': ownerName,
      'phone': phone,
      'role': 'pickup_point_applicant',
    }, onConflict: 'id');

    await _client.from('pickup_point_applications').upsert({
      'user_id': userId,
      'owner_name': ownerName,
      'phone': phone,
      'email': email,
      'pickup_point_name': pickupPointName,
      'address_text': addressText,
      'confirm_address_text': confirmAddressText,
      'city': city,
      'area': area,
      'max_orders_per_day': maxOrdersPerDay,
      'working_days': workingDays,
      'opens_at': opensAt,
      'closes_at': closesAt,
      'commission_type': commissionType,
      'commission_value': commissionValue,
      'commission_plan': commissionPlan,
      'preferred_payment_method': preferredPaymentMethod,
      'payment_handling_method':
          paymentHandlingMethod ?? preferredPaymentMethod,
      'storage_tier': storageTier,
      'estimated_storage_sqm': estimatedStorageSqm,
      'has_shelves': hasShelves,
      'estimated_capacity_units': estimatedCapacityUnits,
      'shop_image_url': shopImageUrl,
      'id_image_url': idImageUrl,
      'storage_area_image_url': storageAreaImageUrl,
      'shelves_image_url': shelvesImageUrl,
      'verification_status': 'pending',
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
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
<<<<<<< Updated upstream
    await _client.from('driver_company_requests').insert({
      'driver_profile_id': driverProfileId,
      'company_id': companyId,
    });
=======
    final driver = await _client
        .from('drivers')
        .select('id, company_id, verification_status')
        .eq('profile_id', driverProfileId)
        .maybeSingle();

    final linkedCompanyId = driver?['company_id']?.toString();
    final verificationStatus = driver?['verification_status']
        ?.toString()
        .trim()
        .toLowerCase();

    if (linkedCompanyId != null && linkedCompanyId.isNotEmpty) {
      if (linkedCompanyId == companyId && verificationStatus == 'approved') {
        throw Exception('You are already linked to this delivery company.');
      }
      throw Exception(
        'You are already linked to a delivery company. Leave or get removed before requesting another one.',
      );
    }

    final existingSameCompany = await _client
        .from('driver_company_requests')
        .select('id, request_status')
        .eq('driver_profile_id', driverProfileId)
        .eq('company_id', companyId)
        .maybeSingle();

    final sameCompanyStatus = existingSameCompany?['request_status']
        ?.toString()
        .trim()
        .toLowerCase();
    if (sameCompanyStatus == 'pending') {
      throw Exception('You already sent a request to this delivery company.');
    }
    if (sameCompanyStatus == 'approved') {
      throw Exception('You are already approved for this delivery company.');
    }

    final existingPending = await _client
        .from('driver_company_requests')
        .select('id')
        .eq('driver_profile_id', driverProfileId)
        .eq('request_status', 'pending')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existingPending != null) {
      throw Exception('You already have a pending company request.');
    }

    final createdAt = DateTime.now().toUtc().toIso8601String();
    if (existingSameCompany != null) {
      await _client
          .from('driver_company_requests')
          .update({'request_status': 'pending', 'created_at': createdAt})
          .eq('id', existingSameCompany['id'].toString());
    } else {
      await _client.from('driver_company_requests').insert({
        'driver_profile_id': driverProfileId,
        'company_id': companyId,
        'request_status': 'pending',
        'created_at': createdAt,
      });
    }

    await _client
        .from('drivers')
        .update({
          'verification_status': 'pending',
          // Driver remains unlinked until company explicitly accepts request.
          'company_id': null,
        })
        .eq('profile_id', driverProfileId);
    await _client
        .from('drivers')
        .update({
          'verification_status': 'pending',
          'company_id': null,
        })
        .eq('id', driverProfileId);
>>>>>>> Stashed changes
  }

  Future<List<Map<String, dynamic>>>
  getDriverRequestsForCurrentCompany() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

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
          .select('profile_id, verification_status')
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
      });
    }

    return result;
  }

  Future<void> acceptDriverRequest({
    required String requestId,
    required String driverProfileId,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    await _client
        .from('driver_company_requests')
        .update({'request_status': 'approved'})
        .eq('id', requestId);

<<<<<<< Updated upstream
    await _client
        .from('drivers')
        .update({'verification_status': 'approved', 'company_id': user.id})
        .eq('profile_id', driverProfileId);
=======
    await _updateDriverRowsWithSchemaFallback(
      profileId: driverProfileId,
      values: {
        'verification_status': 'approved',
        'company_id': requestCompanyId,
        'availability_status': 'unavailable',
        'is_available': false,
        'is_active_shift': false,
        'shift_ended_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    await _updateDriverRowsWithSchemaFallback(
      driverId: driverProfileId,
      values: {
        'verification_status': 'approved',
        'company_id': requestCompanyId,
        'availability_status': 'unavailable',
        'is_available': false,
        'is_active_shift': false,
        'shift_ended_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
>>>>>>> Stashed changes
  }

  Future<void> rejectDriverRequest({
    required String requestId,
    required String driverProfileId,
  }) async {
    await _client
        .from('driver_company_requests')
        .update({'request_status': 'rejected'})
        .eq('id', requestId);

<<<<<<< Updated upstream
=======
    await _updateDriverRowsWithSchemaFallback(
      profileId: driverProfileId,
      values: {
        'verification_status': 'rejected',
        'company_id': null,
        'availability_status': 'unavailable',
        'is_available': false,
        'is_active_shift': false,
        'shift_ended_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    await _updateDriverRowsWithSchemaFallback(
      driverId: driverProfileId,
      values: {
        'verification_status': 'rejected',
        'company_id': null,
        'availability_status': 'unavailable',
        'is_available': false,
        'is_active_shift': false,
        'shift_ended_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> cancelLatestPendingDriverRequest() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final driver = await _client
        .from('drivers')
        .select('id, company_id, verification_status')
        .eq('profile_id', user.id)
        .maybeSingle();

    final linkedCompanyId = driver?['company_id']?.toString();
    if (linkedCompanyId != null && linkedCompanyId.isNotEmpty) {
      throw Exception(
        'You are already linked to a delivery company. This request cannot be cancelled from here.',
      );
    }

    final latestPendingRequest = await _client
        .from('driver_company_requests')
        .select('id, request_status')
        .eq('driver_profile_id', user.id)
        .eq('request_status', 'pending')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (latestPendingRequest == null) {
      throw Exception('No pending delivery company request was found.');
    }

>>>>>>> Stashed changes
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
          'id, merchant_id, branch_id, customer_profile_id, pickup_point_id, delivery_company_id, status, '
          'tracking_code, customer_name, customer_phone, customer_address_text, created_at, updated_at',
        )
        .eq('delivery_company_id', companyId)
        .order('created_at', ascending: false);

    final orders = List<Map<String, dynamic>>.from(orderRows);
    if (orders.isEmpty) return [];

    final orderIds = orders
        .map((order) => order['id']?.toString())
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
    for (final assignment in assignments) {
      final orderId = assignment['order_id']?.toString();
      if (orderId == null || orderId.isEmpty) continue;
      assignmentByOrderId.putIfAbsent(orderId, () => assignment);
    }

    Map<String, Map<String, dynamic>> orderAddressByOrderId = {};
    try {
      final orderAddressRows = await _client
          .from('order_addresses')
          .select('*')
          .inFilter('order_id', orderIds);

      orderAddressByOrderId = {
        for (final row in List<Map<String, dynamic>>.from(orderAddressRows))
          if (row['order_id'] != null) row['order_id'].toString(): row,
      };
    } catch (_) {
      orderAddressByOrderId = {};
    }

    final merchantIds = orders
        .map((order) => order['merchant_id']?.toString())
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

    final pickupIds = orders
        .map((order) => order['pickup_point_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final customerProfileIds = orders
        .map((order) => order['customer_profile_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final driverIds = assignments
        .map((assignment) => assignment['driver_id']?.toString())
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

    final branchById = {
      for (final branch in branches)
        if (branch['id'] != null) branch['id'].toString(): branch,
    };

    final allMerchantIds = <String>{
      ...merchantIds,
      ...branches
          .map((branch) => branch['merchant_id']?.toString())
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

    final merchantById = {
      for (final merchant in merchants)
        if (merchant['id'] != null) merchant['id'].toString(): merchant,
    };

    final pickups = pickupIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('pickup_points')
                .select('id, name, address_text')
                .inFilter('id', pickupIds),
          );

    final pickupById = {
      for (final pickup in pickups)
        if (pickup['id'] != null) pickup['id'].toString(): pickup,
    };

    final drivers = driverIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('drivers')
                .select('id, profile_id, company_id, vehicle_type')
                .inFilter('id', driverIds)
                .eq('company_id', companyId),
          );

    final driverById = {
      for (final driver in drivers)
        if (driver['id'] != null) driver['id'].toString(): driver,
    };

    final profileIds = <String>{
      ...customerProfileIds,
      ...drivers
          .map((driver) => driver['profile_id']?.toString())
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

    final profileById = {
      for (final profile in profiles)
        if (profile['id'] != null) profile['id'].toString(): profile,
    };

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
        'vehicle_type': hasValidDriver
            ? (driver?['vehicle_type']?.toString())
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
            .map((row) => row['order_id']?.toString())
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
          .map((row) => row['merchant_id']?.toString())
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
      for (final row in allActiveMappings) {
        final merchantId = row['merchant_id']?.toString();
        final mappedCompanyId = row['company_id']?.toString();
        if (merchantId == null ||
            merchantId.isEmpty ||
            mappedCompanyId == null ||
            mappedCompanyId.isEmpty) {
          continue;
        }
        companiesByMerchant
            .putIfAbsent(merchantId, () => <String>{})
            .add(mappedCompanyId);
      }

      final safeMerchantIds = companiesByMerchant.entries
          .where(
            (entry) =>
                entry.value.length == 1 && entry.value.first == companyId,
          )
          .map((entry) => entry.key)
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
            'id, profile_id, company_id, vehicle_type, verification_status',
          )
          .eq('company_id', user.id)
          .eq('verification_status', 'approved'),
    );

    if (driversRows.isEmpty) return [];

    final profileIds = driversRows
        .map((row) => row['profile_id']?.toString() ?? row['id']?.toString())
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

    final profileById = {
      for (final row in profiles)
        if (row['id'] != null) row['id'].toString(): row,
    };

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
            'vehicle_type': row['vehicle_type']?.toString(),
            'verification_status': row['verification_status']?.toString(),
          };
        })
        .where((row) => row.isNotEmpty)
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
    if (orderList.isEmpty) {
      throw Exception('Order not found');
    }

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
    if (driverList.isEmpty) {
      throw Exception('Selected driver not found');
    }

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
    if (previousDriverId == driverId && currentStatus == 'assigned') {
      return;
    }

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

    const nextStatus = 'assigned';
    await _client
        .from('orders')
        .update({
          'status': nextStatus,
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
    if (orderList.isEmpty) {
      throw Exception('Order not found');
    }

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
    if (assignments.isEmpty) {
      return;
    }

    final assignment = assignments.first;
    final hadDriver =
        (assignment['driver_id']?.toString().trim().isNotEmpty ?? false);
    if (!hadDriver) {
      return;
    }

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
    final response = await _client
        .from('driver_locations')
        .select()
        .eq('driver_id', driverId)
        .maybeSingle();

    return response;
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
      if (text.isNotEmpty && text != '-') {
        return text;
      }
    }
    return null;
  }
}
