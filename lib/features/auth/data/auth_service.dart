import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/domain/delivery_constraints.dart';

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
  }) async {
    if (shouldCreateUser && _client.auth.currentUser != null) {
      await _client.auth.signOut();
    }

    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: shouldCreateUser,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<void> requestDriverSignupOtp({required String email}) async {
    final response = await _client.functions.invoke(
      'complete-driver-signup',
      body: {'action': 'request_otp', 'email': email, 'purpose': 'driver_signup'},
    );

    final payload = response.data;
    final sent = payload is Map && payload['sent'] == true;
    if (!sent) {
      final message = _functionErrorMessage(
        payload,
        fallback: 'Unable to send verification code.',
      );
      throw Exception(message);
    }
  }

  Future<void> verifyDriverSignupOtp({
    required String email,
    required String code,
  }) async {
    final response = await _client.functions.invoke(
      'complete-driver-signup',
      body: {
        'action': 'verify_otp',
        'email': email,
        'purpose': 'driver_signup',
        'code': code,
      },
    );

    final payload = response.data;
    final verified = payload is Map && payload['verified'] == true;
    if (!verified) {
      final message = _functionErrorMessage(
        payload,
        fallback: 'Invalid or expired verification code.',
      );
      throw Exception(message);
    }
  }

  Future<void> completeDriverSignup({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String city,
    required String companyId,
    required String vehicleType,
  }) async {
    final response = await _client.functions.invoke(
      'complete-driver-signup',
      body: {
        'action': 'complete_signup',
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
        'city': city,
        'company_id': companyId,
        'vehicle_type': vehicleType,
      },
    );

    final payload = response.data;
    final completed = payload is Map && payload['completed'] == true;
    if (!completed) {
      final message = _functionErrorMessage(
        payload,
        fallback: 'Unable to create driver account.',
      );
      throw Exception(message);
    }

    await signInWithPassword(email: email, password: password);
  }

  Future<void> resendSignupOtp({required String email}) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  Future<void> resendLoginOtp({required String email}) async {
    await _client.auth.resend(type: OtpType.email, email: email);
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    required AuthFlowMode mode,
  }) async {
    final otpType = mode == AuthFlowMode.login ? OtpType.email : OtpType.signup;
    try {
      return await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: otpType,
      );
    } on AuthException catch (_) {
      // Some signup flows may receive an email OTP type instead of signup.
      // Retry once with OtpType.email for robustness.
      if (mode == AuthFlowMode.driverSignup) {
        return await _client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.email,
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> setCurrentUserPassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> deleteCurrentDriverAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final response = await _client.functions.invoke('delete-driver-account');
    final payload = response.data;
    final ok = payload is Map && payload['success'] == true;

    if (!ok) {
      final message = payload is Map
          ? payload['error']?.toString()
          : null;
      throw Exception(message ?? 'Failed to delete driver account');
    }

    try {
      await signOut();
    } catch (_) {}
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

  Future<List<String>> _getCurrentCompanyIds() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final ids = <String>{user.id};

    try {
      final companyUsers = await _client
          .from('company_users')
          .select('company_id')
          .eq('profile_id', user.id);

      for (final row in List<Map<String, dynamic>>.from(companyUsers)) {
        final companyId = row['company_id']?.toString();
        if (companyId != null && companyId.isNotEmpty) {
          ids.add(companyId);
        }
      }
    } catch (_) {}

    return ids.toList();
  }

  void _assertCompanyAccess({
    required String companyId,
    required List<String> allowedCompanyIds,
  }) {
    if (!allowedCompanyIds.contains(companyId)) {
      throw Exception('Order does not belong to your delivery company');
    }
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

    // Prefer concrete role-specific records over profile.role text.
    // This avoids misrouting when profile.role is stale (eg. user has a driver
    // row but profile role was not updated yet).
    final driver = await getDriverByProfileId(user.id);
    if (driver != null) {
      final status = await checkDriverStatus();
      final requestStatus = await getLatestDriverRequestStatus();
      if (status == 'approved') return '/driver-dashboard';
      if (requestStatus == 'pending') return '/waiting-approval';
      if (status == 'rejected' || requestStatus == 'rejected') {
        return '/rejected';
      }
      if (status == 'pending') return '/waiting-approval';
      if (requestStatus == 'approved') return '/driver-dashboard';
      return '/select-company';
    }

    final role = await getCurrentRole();

    switch (role) {
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

  Future<String?> getLatestDriverRequestStatus() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final request = await _client
        .from('driver_company_requests')
        .select('request_status')
        .eq('driver_profile_id', user.id)
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
    required String companyId,
    required String vehicleType,
  }) async {
    final normalizedVehicleType = _normalizeVehicleType(vehicleType);
    final capacity = DeliveryConstraintDefaults.capacityForVehicleType(
      normalizedVehicleType,
    );

    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'role': 'driver',
    }, onConflict: 'id');

    final driverPayload = <String, dynamic>{
      // Many RLS policies on drivers require id to match auth.uid().
      // Keep id/profile_id aligned to the current authenticated user.
      'id': userId,
      'profile_id': userId,
      'company_id': null,
      'verification_status': 'pending',
      'vehicle_type': normalizedVehicleType,
      'capacity_weight': capacity.weightKg,
      'capacity_volume': capacity.volumeCm3,
      'capacity_item_count': capacity.itemCount,
      'city': city,
      'service_area': city,
      'availability_status': 'unavailable',
      'is_available': false,
      'is_active_shift': false,
      'current_load_weight': 0,
      'current_load_volume': 0,
      'current_load_item_count': 0,
    };

    await _upsertDriverWithSchemaFallback(driverPayload);

    await sendDriverRequest(driverProfileId: userId, companyId: companyId);
  }

  Future<void> createCompanyProfile({
    required String userId,
    required String adminName,
    required String companyName,
    required String phone,
    required String email,
    required String exactAddress,
    required String city,
    required String area,
    required double latitude,
    required double longitude,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': adminName,
      'phone': phone,
      'role': 'company_admin',
    });

    await _client.from('delivery_companies').upsert({
      'id': userId,
      'name': companyName,
      'phone': phone,
      'email': email,
      'location': city,
      'address_text': exactAddress,
      'exact_address': exactAddress,
      'city': city,
      'area': area,
      'lat': latitude,
      'lng': longitude,
      'latitude': latitude,
      'longitude': longitude,
    }, onConflict: 'id');

    try {
      await _client.from('company_users').upsert({
        'profile_id': userId,
        'company_id': userId,
        'role': 'owner',
      }, onConflict: 'profile_id,company_id');
    } catch (_) {}
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
  }

  Future<List<Map<String, dynamic>>>
  getDriverRequestsForCurrentCompany() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }
    final companyIds = await _getCurrentCompanyIds();

    final requests = await _client
        .from('driver_company_requests')
        .select()
        .inFilter('company_id', companyIds)
        .order('created_at', ascending: false);

    List<Map<String, dynamic>> result = [];

    for (final request in requests) {
      final driverProfileId = request['driver_profile_id'];

      final profile = await _client
          .from('profiles')
          .select('id, full_name, phone, role')
          .eq('id', driverProfileId)
          .maybeSingle();

      Map<String, dynamic>? driver = await _client
          .from('drivers')
          .select(
            'id, profile_id, verification_status, vehicle_type, capacity_weight, capacity_volume, capacity_item_count',
          )
          .eq('profile_id', driverProfileId)
          .maybeSingle();
      driver ??= await _client
          .from('drivers')
          .select(
            'id, profile_id, verification_status, vehicle_type, capacity_weight, capacity_volume, capacity_item_count',
          )
          .eq('id', driverProfileId)
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
        'capacity_weight': driver?['capacity_weight'],
        'capacity_volume': driver?['capacity_volume'],
        'capacity_item_count': driver?['capacity_item_count'],
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
    final companyIds = await _getCurrentCompanyIds();
    final request = await _client
        .from('driver_company_requests')
        .select('id, company_id')
        .eq('id', requestId)
        .maybeSingle();
    final requestCompanyId = request?['company_id']?.toString();
    if (requestCompanyId == null || requestCompanyId.isEmpty) {
      throw Exception('Driver request not found');
    }
    _assertCompanyAccess(
      companyId: requestCompanyId,
      allowedCompanyIds: companyIds,
    );

    await _client
        .from('driver_company_requests')
        .update({
          'request_status': 'approved',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId);

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
  }

  Future<void> rejectDriverRequest({
    required String requestId,
    required String driverProfileId,
  }) async {
    final companyIds = await _getCurrentCompanyIds();
    final request = await _client
        .from('driver_company_requests')
        .select('id, company_id')
        .eq('id', requestId)
        .maybeSingle();
    final requestCompanyId = request?['company_id']?.toString();
    if (requestCompanyId == null || requestCompanyId.isEmpty) {
      throw Exception('Driver request not found');
    }
    _assertCompanyAccess(
      companyId: requestCompanyId,
      allowedCompanyIds: companyIds,
    );

    await _client
        .from('driver_company_requests')
        .update({
          'request_status': 'rejected',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId);

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

    await _client
        .from('driver_company_requests')
        .delete()
        .eq('id', latestPendingRequest['id'].toString());

    final verificationStatus = driver?['verification_status']
        ?.toString()
        .trim()
        .toLowerCase();
    if (verificationStatus == 'pending') {
      await _client
          .from('drivers')
          .update({'verification_status': null})
          .eq('profile_id', user.id);
    }
  }

  Future<void> startDriverShift({required String driverId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _updateDriverRowsWithSchemaFallback(
      driverId: driverId,
      requireApprovedStatus: true,
      values: {
        'availability_status': 'available',
        'is_available': true,
        'is_active_shift': true,
        'shift_started_at': now,
        'shift_ended_at': null,
        'shift_start_at': now,
        'shift_end_at': null,
        'updated_at': now,
      },
    );
  }

  Future<void> endDriverShift({required String driverId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _updateDriverRowsWithSchemaFallback(
      driverId: driverId,
      values: {
        'availability_status': 'unavailable',
        'is_available': false,
        'is_active_shift': false,
        'shift_ended_at': now,
        'shift_end_at': now,
        'updated_at': now,
      },
    );
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
    final companyIds = await _getCurrentCompanyIds();

    for (final companyId in companyIds) {
      await _backfillLegacyOrderCompanyLinks(companyId);
    }
    unawaited(_touchDriverRequestBackfill());

    final orders = await _getCompanyOrderRows(companyIds);
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
        .inFilter('company_id', companyIds)
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

    Map<String, Map<String, dynamic>> autoAssignmentEventByOrderId = {};
    try {
      final eventRows = await _client
          .from('order_events')
          .select('order_id, event_type, note, metadata, created_at')
          .inFilter('order_id', orderIds)
          .order('created_at', ascending: false);

      for (final row in List<Map<String, dynamic>>.from(eventRows)) {
        final orderId = row['order_id']?.toString();
        if (orderId == null || orderId.isEmpty) continue;
        final note = row['note']?.toString().toLowerCase() ?? '';
        final metadataText = row['metadata']?.toString().toLowerCase() ?? '';
        final looksLikeAutoAssignment =
            note.contains('automatic') ||
            note.contains('auto assignment') ||
            metadataText.contains('assignment_status');
        if (!looksLikeAutoAssignment) continue;
        autoAssignmentEventByOrderId.putIfAbsent(orderId, () => row);
      }
    } catch (_) {
      autoAssignmentEventByOrderId = {};
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
                .inFilter('id', driverIds),
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
      final assignmentStatus = order['assignment_status']?.toString();
      final hasAssignmentMetadata =
          order.containsKey('assignment_status') ||
          order.containsKey('assignment_failure_reason') ||
          order.containsKey('assigned_driver_id');
      final autoAssignmentEvent = autoAssignmentEventByOrderId[orderId];
      final autoAssignmentEventNote = autoAssignmentEvent?['note']?.toString();
      final autoAssignmentReason =
          order['assignment_failure_reason']?.toString() ??
          autoAssignmentEventNote;
      final eventSuggestsFailure =
          autoAssignmentEventNote?.toLowerCase().contains('failed') == true ||
          autoAssignmentEvent?['metadata']?.toString().toLowerCase().contains(
                'assignment_failed',
              ) ==
              true;

      return {
        'assignment_id': assignment?['id'],
        'order_id': orderId,
        'tracking_code': _firstNonEmpty([order['tracking_code'], orderId]),
        'status': order['status']?.toString() ?? 'created',
        'assignment_status': assignmentStatus ?? 'pending_assignment',
        'has_assignment_metadata': hasAssignmentMetadata,
        'auto_assignment_failed':
            const {
              'assignment_failed',
              'needs_manual_assignment',
              'unassigned',
            }.contains(assignmentStatus?.trim().toLowerCase() ?? '') ||
            eventSuggestsFailure,
        'auto_assignment_reason': autoAssignmentReason,
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

  Future<List<Map<String, dynamic>>> _getCompanyOrderRows(
    List<String> companyIds,
  ) async {
    try {
      final orderRows = await _client
          .from('orders')
          .select(
            'id, merchant_id, branch_id, customer_profile_id, pickup_point_id, delivery_company_id, status, '
            'tracking_code, customer_name, customer_phone, customer_address_text, '
            'assignment_status, assigned_driver_id, assignment_failure_reason, '
            'created_at, updated_at',
          )
          .inFilter('delivery_company_id', companyIds)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(orderRows);
    } on PostgrestException catch (error) {
      if (!_isMissingOrderAssignmentMetadataError(error)) rethrow;

      final orderRows = await _client
          .from('orders')
          .select(
            'id, merchant_id, branch_id, customer_profile_id, pickup_point_id, delivery_company_id, status, '
            'tracking_code, customer_name, customer_phone, customer_address_text, '
            'created_at, updated_at',
          )
          .inFilter('delivery_company_id', companyIds)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(orderRows);
    }
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
    final companyIds = await _getCurrentCompanyIds();

    final driverById = <String, Map<String, dynamic>>{};

    final linkedDriverRows = List<Map<String, dynamic>>.from(
      await _client
          .from('drivers')
          .select(
            'id, profile_id, company_id, vehicle_type, verification_status',
          )
          .inFilter('company_id', companyIds)
          .eq('verification_status', 'approved'),
    );

    for (final row in linkedDriverRows) {
      final id = row['id']?.toString();
      if (id != null && id.isNotEmpty) {
        driverById[id] = row;
      }
    }

    try {
      final approvedRequests = List<Map<String, dynamic>>.from(
        await _client
            .from('driver_company_requests')
            .select('driver_profile_id, company_id, request_status')
            .inFilter('company_id', companyIds)
            .eq('request_status', 'approved'),
      );

      final requestProfileIds = approvedRequests
          .map((row) => row['driver_profile_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (requestProfileIds.isNotEmpty) {
        final requestedDriverRows = <Map<String, dynamic>>[
          ...List<Map<String, dynamic>>.from(
            await _client
                .from('drivers')
                .select(
                  'id, profile_id, company_id, vehicle_type, verification_status',
                )
                .inFilter('profile_id', requestProfileIds),
          ),
          ...List<Map<String, dynamic>>.from(
            await _client
                .from('drivers')
                .select(
                  'id, profile_id, company_id, vehicle_type, verification_status',
                )
                .inFilter('id', requestProfileIds),
          ),
        ];

        final requestCompanyByProfileId = {
          for (final row in approvedRequests)
            if (row['driver_profile_id'] != null)
              row['driver_profile_id'].toString(): row['company_id']
                  ?.toString(),
        };

        for (final row in requestedDriverRows) {
          final id = row['id']?.toString();
          final profileId = row['profile_id']?.toString();
          if (id == null || id.isEmpty) continue;
          final requestCompanyId = requestCompanyByProfileId[profileId];
          driverById.putIfAbsent(id, () {
            return {...row, '_approved_request_company_id': requestCompanyId};
          });
        }
      }
    } catch (_) {}

    final driversRows = driverById.values.toList();

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
            'verification_status': row['_approved_request_company_id'] != null
                ? 'approved'
                : row['verification_status']?.toString(),
          };
        })
        .where((row) => row.isNotEmpty)
        .toList();
  }

  Future<void> removeDriverFromCurrentCompany({
    required String driverId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final companyIds = await _getCurrentCompanyIds();

    final driver = await _client
        .from('drivers')
        .select('id, profile_id, company_id')
        .eq('id', driverId)
        .maybeSingle();

    if (driver == null) {
      throw Exception('Driver not found');
    }

    final companyId = driver['company_id']?.toString();
    if (companyId == null || companyId.isEmpty) {
      throw Exception('Driver is not linked to a delivery company');
    }
    _assertCompanyAccess(companyId: companyId, allowedCompanyIds: companyIds);

    await _updateDriverRowsWithSchemaFallback(
      driverId: driverId,
      values: {
        'company_id': null,
        'verification_status': 'rejected',
        'availability_status': 'unavailable',
        'is_available': false,
        'is_active_shift': false,
        'shift_ended_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    final profileId = driver['profile_id']?.toString();
    if (profileId != null && profileId.isNotEmpty) {
      try {
        await _client
            .from('driver_company_requests')
            .update({
              'request_status': 'rejected',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('driver_profile_id', profileId)
            .eq('company_id', companyId)
            .eq('request_status', 'approved');
      } catch (_) {}
    }
  }

  Future<bool> _hasApprovedDriverCompanyRequest({
    required String? driverProfileId,
    required String companyId,
  }) async {
    if (driverProfileId == null || driverProfileId.isEmpty) return false;

    try {
      final request = await _client
          .from('driver_company_requests')
          .select('id')
          .eq('driver_profile_id', driverProfileId)
          .eq('company_id', companyId)
          .eq('request_status', 'approved')
          .limit(1)
          .maybeSingle();

      return request != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> assignOrderToDriver({
    required String orderId,
    required String driverId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final companyIds = await _getCurrentCompanyIds();

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
    _assertCompanyAccess(
      companyId: orderCompanyId,
      allowedCompanyIds: companyIds,
    );

    final driverRows = await _client
        .from('drivers')
        .select('id, company_id, profile_id, verification_status')
        .eq('id', driverId)
        .limit(1);

    final driverList = List<Map<String, dynamic>>.from(driverRows);
    if (driverList.isEmpty) {
      throw Exception('Selected driver not found');
    }

    final driver = driverList.first;
    final driverCompanyId = driver['company_id']?.toString();
    final driverProfileId = driver['profile_id']?.toString();
    final driverStatus = driver['verification_status']
        ?.toString()
        .trim()
        .toLowerCase();

    final hasApprovedCompanyRequest = await _hasApprovedDriverCompanyRequest(
      driverProfileId: driverProfileId,
      companyId: orderCompanyId,
    );

    if (driverCompanyId != orderCompanyId && !hasApprovedCompanyRequest) {
      throw Exception('Cannot assign order to a driver from another company');
    }

    if (driverStatus != 'approved' && !hasApprovedCompanyRequest) {
      throw Exception('Manual fallback can only use approved drivers');
    }

    if (driverCompanyId != orderCompanyId || driverStatus != 'approved') {
      await _client
          .from('drivers')
          .update({
            'company_id': orderCompanyId,
            'verification_status': 'approved',
          })
          .eq('id', driverId);
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
        .eq('company_id', orderCompanyId)
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
        'company_id': orderCompanyId,
        'order_id': orderId,
        'driver_id': driverId,
        'assigned_at': assignedAt,
        'accepted_at': null,
        'completed_at': null,
      });
    }

    const nextStatus = 'assigned';
    await _updateOrderForCompany(
      orderId: orderId,
      companyId: orderCompanyId,
      values: {
        'status': nextStatus,
        'assignment_status': 'assigned',
        'assigned_driver_id': driverId,
        'assignment_failure_reason': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

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
    final companyIds = await _getCurrentCompanyIds();

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
    _assertCompanyAccess(
      companyId: orderCompanyId,
      allowedCompanyIds: companyIds,
    );
    if (_companyTerminalStatuses.contains(currentStatus)) {
      throw Exception('Cannot unassign a closed or in-progress order');
    }

    final assignmentRows = await _client
        .from('assignments')
        .select('id, driver_id')
        .eq('company_id', orderCompanyId)
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

    await _updateOrderForCompany(
      orderId: orderId,
      companyId: orderCompanyId,
      values: {
        'status': 'pending',
        'assignment_status': 'needs_manual_assignment',
        'assigned_driver_id': null,
        'assignment_failure_reason': 'Driver unassigned by delivery company',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    await _client.from('order_events').insert({
      'order_id': orderId,
      'event_type': 'note_added',
      'created_by': user.id,
      'note': 'Driver unassigned by delivery company',
    });
  }

  Future<void> _updateOrderForCompany({
    required String orderId,
    required String companyId,
    required Map<String, dynamic> values,
  }) async {
    try {
      await _client
          .from('orders')
          .update(values)
          .eq('id', orderId)
          .eq('delivery_company_id', companyId);
    } on PostgrestException catch (error) {
      if (!_isMissingOrderAssignmentMetadataError(error)) rethrow;

      final legacyValues = Map<String, dynamic>.from(values)
        ..remove('assignment_status')
        ..remove('assigned_driver_id')
        ..remove('assignment_failure_reason');

      await _client
          .from('orders')
          .update(legacyValues)
          .eq('id', orderId)
          .eq('delivery_company_id', companyId);
    }
  }

  bool _isMissingOrderAssignmentMetadataError(PostgrestException error) {
    final message = error.message.toLowerCase();
    final code = error.code?.toLowerCase();
    final isMissingColumn =
        code == '42703' ||
        code == 'pgrst204' ||
        message.contains('does not exist') ||
        message.contains('could not find');
    if (!isMissingColumn) return false;

    return const [
      'assignment_status',
      'assigned_driver_id',
      'assignment_failure_reason',
    ].any(message.contains);
  }

  Future<Map<String, dynamic>?> getDriverLocationByDriverId(
    String driverId,
  ) async {
    final response = await _client
        .from('driver_locations')
        .select()
        .eq('driver_id', driverId)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  Future<void> upsertDriverLocation({
    required String driverId,
    double? lat,
    double? lng,
    double? heading,
    double? speed,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    if (lat == null || lng == null) {
      await touchDriverLocationPing(driverId: driverId);
      return;
    }

    await _client.from('driver_locations').upsert({
      'driver_id': driverId,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'last_location_ping_at': now,
      'updated_at': now,
    }, onConflict: 'driver_id');

    await _updateDriverRowsWithSchemaFallback(
      driverId: driverId,
      values: {
        'current_location_lat': lat,
        'current_location_lng': lng,
        'last_location_ping_at': now,
        'updated_at': now,
      },
    );
  }

  Future<void> touchDriverLocationPing({required String driverId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('driver_locations')
        .update({'last_location_ping_at': now, 'updated_at': now})
        .eq('driver_id', driverId);

    await _updateDriverRowsWithSchemaFallback(
      driverId: driverId,
      values: {'last_location_ping_at': now, 'updated_at': now},
    );
  }

  Future<void> _touchDriverRequestBackfill() async {}

  User? get currentUser => _client.auth.currentUser;

  String _functionErrorMessage(dynamic payload, {required String fallback}) {
    if (payload is! Map) return fallback;
    final error = payload['error']?.toString().trim();
    final reason = payload['reason']?.toString().trim();
    // Prefer detailed backend reason when available (eg. Resend status/body),
    // otherwise fall back to the generic user-facing error string.
    if (reason != null && reason.isNotEmpty) return reason;
    if (error != null && error.isNotEmpty) return error;
    return fallback;
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

  String _normalizeVehicleType(String vehicleType) {
    final normalized = vehicleType.trim().toLowerCase();
    if (normalized == 'car' || normalized == 'van') return normalized;
    return 'motorcycle';
  }

  Future<void> _upsertDriverWithSchemaFallback(Map<String, dynamic> payload) async {
    final mutablePayload = Map<String, dynamic>.from(payload);

    // Retry a few times in case the local code has newer columns than the DB.
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        await _client.from('drivers').upsert(
          mutablePayload,
          onConflict: 'id',
        );
        return;
      } on PostgrestException catch (error) {
        final missingColumn = _extractMissingDriversColumn(error);
        if (missingColumn == null || !mutablePayload.containsKey(missingColumn)) {
          rethrow;
        }
        mutablePayload.remove(missingColumn);
      }
    }

    throw Exception('Failed to create driver profile due to schema mismatch.');
  }

  Future<void> _updateDriverRowsWithSchemaFallback({
    required Map<String, dynamic> values,
    String? driverId,
    String? profileId,
    bool requireApprovedStatus = false,
  }) async {
    final mutableValues = Map<String, dynamic>.from(values);

    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        var query = _client.from('drivers').update(mutableValues);
        if (driverId != null && driverId.isNotEmpty) {
          query = query.eq('id', driverId);
        }
        if (profileId != null && profileId.isNotEmpty) {
          query = query.eq('profile_id', profileId);
        }
        if (requireApprovedStatus) {
          query = query.eq('verification_status', 'approved');
        }
        await query;
        return;
      } on PostgrestException catch (error) {
        final missingColumn = _extractMissingDriversColumn(error);
        if (missingColumn == null || !mutableValues.containsKey(missingColumn)) {
          rethrow;
        }
        mutableValues.remove(missingColumn);
      }
    }

    throw Exception('Failed to update driver row due to schema mismatch.');
  }

  String? _extractMissingDriversColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    final code = error.code?.toLowerCase();
    final isMissingColumn =
        code == '42703' ||
        code == 'pgrst204' ||
        message.contains('does not exist') ||
        message.contains('could not find');
    if (!isMissingColumn) return null;

    final singleQuoted = RegExp(r"'([^']+)'").allMatches(message).toList();
    for (final match in singleQuoted) {
      final value = match.group(1);
      if (value == null || value == 'drivers') continue;
      return value;
    }
    return null;
  }
}
