import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/domain/delivery_constraints.dart';
import 'package:uuid/uuid.dart';

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
  static const Uuid _uuid = Uuid();

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
    final normalizedEmail = email.trim().toLowerCase();
    return await _client.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
  }

  Future<void> sendOtp({
    required String email,
    required bool shouldCreateUser,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (shouldCreateUser && _client.auth.currentUser != null) {
      await _client.auth.signOut();
    }

    await _client.auth.signInWithOtp(
      email: normalizedEmail,
      shouldCreateUser: shouldCreateUser,
      emailRedirectTo: emailRedirectTo,
      data: data,
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
    final normalizedEmail = email.trim().toLowerCase();
    final preferredType =
        mode == AuthFlowMode.login ? OtpType.email : OtpType.signup;
    final fallbackType = preferredType == OtpType.email
        ? OtpType.signup
        : OtpType.email;
    debugPrint(
      '[OTP_VERIFY] email=$normalizedEmail mode=$mode '
      'preferredType=$preferredType fallbackType=$fallbackType',
    );

    return await _verifyEmailOtp(
      email: normalizedEmail,
      token: token,
      preferredType: preferredType,
      fallbackType: fallbackType,
    );
  }

  Future<AuthResponse> _verifyEmailOtp({
    required String email,
    required String token,
    required OtpType preferredType,
    OtpType? fallbackType,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    AuthException? firstError;

    try {
      return await _client.auth.verifyOTP(
        email: normalizedEmail,
        token: token,
        type: preferredType,
      );
    } on AuthException catch (error) {
      debugPrint(
        '[OTP_VERIFY] preferredType=$preferredType failed '
        'code=${error.code} statusCode=${_extractStatusCode(error)} '
        'message=${error.message}',
      );
      firstError = error;
    }

    if (fallbackType == null || fallbackType == preferredType) {
      throw firstError!;
    }
    if (!_shouldFallbackOtpVerification(firstError)) {
      throw firstError!;
    }

    try {
      return await _client.auth.verifyOTP(
        email: normalizedEmail,
        token: token,
        type: fallbackType,
      );
    } on AuthException catch (fallbackError) {
      debugPrint(
        '[OTP_VERIFY] fallbackType=$fallbackType failed '
        'code=${fallbackError.code} statusCode=${_extractStatusCode(fallbackError)} '
        'message=${fallbackError.message}',
      );
      throw firstError!;
    }
  }

  bool _shouldFallbackOtpVerification(AuthException? error) {
    if (error == null) return false;
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();
    return code == 'invalid_grant' ||
        code == 'invalid_otp' ||
        code == 'otp_invalid' ||
        message.contains('invalid token') ||
        message.contains('token is invalid') ||
        message.contains('token has expired or is invalid');
  }

  String? _extractStatusCode(AuthException error) {
    final raw = error.toString();
    final match = RegExp(r'statusCode:\s*([0-9]+)').firstMatch(raw);
    return match?.group(1);
  }

  Future<void> _resendEmailOtp({
    required String email,
    required OtpType preferredType,
    OtpType? fallbackType,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    AuthException? firstError;

    try {
      await _client.auth.resend(type: preferredType, email: normalizedEmail);
      return;
    } on AuthException catch (error) {
      firstError = error;
    }

    if (fallbackType == null || fallbackType == preferredType) {
      throw firstError!;
    }

    try {
      await _client.auth.resend(type: fallbackType, email: normalizedEmail);
    } on AuthException {
      throw firstError!;
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
    final lat = _toDouble(application['lat']);
    final lng = _toDouble(application['lng']);
    if (lat == null || lng == null) {
      throw Exception(
        'Pickup point application is missing map coordinates (lat/lng). '
        'Please update location coordinates before approval.',
      );
    }

    final pickupPayload = <String, dynamic>{
      'owner_profile_id': applicantId,
      'created_by': admin.id,
      'name': application['pickup_point_name'],
      'owner_name': application['owner_name'],
      'phone': application['phone'],
      'email': application['email'],
      'address_text': application['address_text'],
      'lat': lat,
      'lng': lng,
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
    } catch (_) {}

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

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
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

    Map<String, dynamic>? existingMerchantUser;
    try {
      existingMerchantUser = await _client
          .from('merchant_users')
          .select('merchant_id')
          .eq('profile_id', userId)
          .maybeSingle();
    } catch (_) {
      existingMerchantUser = null;
    }

    String merchantId;

    if (existingMerchantUser != null &&
        existingMerchantUser['merchant_id'] != null) {
      merchantId = existingMerchantUser['merchant_id'].toString();
    } else {
      merchantId = _uuid.v4();
      debugPrint(
        '[MERCHANT_SIGNUP] creating merchant_business '
        'businessName=$businessName userId=$userId',
      );
      try {
        await _client.from('merchant_businesses').insert({
          'id': merchantId,
          'name': businessName,
        });

        await _client.from('merchant_users').insert({
          'profile_id': userId,
          'merchant_id': merchantId,
          'role': 'owner',
        });
      } on PostgrestException catch (e) {
        debugPrint(
          '[MERCHANT_SIGNUP_RLS_ERROR] code=${e.code} message=${e.message} '
          'details=${e.details} hint=${e.hint}',
        );
        rethrow;
      }
    }

    Map<String, dynamic>? existingBranch;
    try {
      existingBranch = await _client
          .from('merchant_branches')
          .select('id')
          .eq('merchant_id', merchantId)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      existingBranch = null;
    }

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
    double? lat,
    double? lng,
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
      'lat': lat,
      'lng': lng,
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
          'company_id': companyId,
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
                .select('id, name, address_text, lat, lng, city, area')
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
      final rawDriverId = assignment?['driver_id']?.toString().trim();
      final hasLinkedDriverOnAssignment =
          rawDriverId != null && rawDriverId.isNotEmpty;
      final driver = hasLinkedDriverOnAssignment
          ? driverById[rawDriverId]
          : null;
      final driverProfileId = driver?['profile_id']?.toString();
      final driverProfile = driverProfileId == null
          ? null
          : profileById[driverProfileId];

      /// Keep [driver_id] whenever the assignment row links a driver, even if
      /// the drivers join failed (RLS, deleted row). Never show "assigned"
      /// order status with a blank driver line because [driver_name] was null.
      final String? resolvedDriverName = !hasLinkedDriverOnAssignment
          ? null
          : _firstNonEmpty([
              driverProfile?['full_name'],
              if (driver != null) 'Driver (name not on file)',
              'Unknown driver (record missing or inaccessible)',
            ]);
      final String? resolvedDriverPhone =
          driverProfile != null ? driverProfile['phone']?.toString() : null;
      final String? resolvedVehicleType =
          driver != null ? driver['vehicle_type']?.toString() : null;

      final customerProfileId = order['customer_profile_id']?.toString();
      final customerProfile = customerProfileId == null
          ? null
          : profileById[customerProfileId];
      final branch = branchById[order['branch_id']?.toString()];
      final sourcePickup = pickupById[order['pickup_point_id']?.toString()];
      final destinationPickup =
          pickupById[order['destination_pickup_point_id']?.toString()];
      final pickupSourceType =
          order['pickup_source_type']?.toString().trim().toLowerCase() ?? 'store';
      final dropoffType =
          order['dropoff_type']?.toString().trim().toLowerCase() ?? 'home';
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
      final hasAutoAssignmentReason =
          autoAssignmentReason != null &&
          autoAssignmentReason.trim().isNotEmpty;
      final eventSuggestsFailure =
          autoAssignmentEventNote?.toLowerCase().contains('failed') == true ||
          autoAssignmentEvent?['metadata']?.toString().toLowerCase().contains(
                'assignment_failed',
              ) ==
              true ||
          autoAssignmentEvent != null;

      final pickupName = pickupSourceType == 'pickup_point'
          ? _firstNonEmpty([sourcePickup?['name'], branch?['name']]) ??
              'Pickup point'
          : _firstNonEmpty([branch?['name'], sourcePickup?['name']]) ?? 'Store';
      final pickupAddress = pickupSourceType == 'pickup_point'
          ? _firstNonEmpty([sourcePickup?['address_text'], branch?['address_text']]) ??
              'No pickup address'
          : _firstNonEmpty([branch?['address_text'], sourcePickup?['address_text']]) ??
              'No pickup address';
      final status = order['status']?.toString().trim().toLowerCase() ?? '';
      final movedToPickupStatuses = const {
        'failed',
        'customer_not_available',
        'pending_pickup_point_delivery',
        'dropped_at_pickup_point',
      };
      final hasBackupPickupPoint =
          dropoffType == 'home' && destinationPickup != null;
      final backupIsActiveDropoff =
          hasBackupPickupPoint && movedToPickupStatuses.contains(status);
      final activeDropoffAddress = dropoffType == 'pickup_point_specific'
          ? _firstNonEmpty([
              destinationPickup?['address_text'],
              _destinationPickupPointDropoffLabel(destinationPickup),
            ])
          : (backupIsActiveDropoff
                ? _firstNonEmpty([
                    destinationPickup?['address_text'],
                    _destinationPickupPointDropoffLabel(destinationPickup),
                  ])
                : _firstNonEmpty([
                    address?['dropoff_address_text'],
                    address?['dropoff_address'],
                    order['customer_address_text'],
                    order['dropoff_address_text'],
                  ]));
      final activeDropoffLat = dropoffType == 'pickup_point_specific'
          ? _toDouble(destinationPickup?['lat'])
          : _toDouble(order['dropoff_location_lat']) ??
                _toDouble(order['customer_lat']);
      final activeDropoffLng = dropoffType == 'pickup_point_specific'
          ? _toDouble(destinationPickup?['lng'])
          : _toDouble(order['dropoff_location_lng']) ??
                _toDouble(order['customer_lng']);
      final activeDropoffName = dropoffType == 'pickup_point_specific'
          ? (_firstNonEmpty([destinationPickup?['name']]) ?? 'Pickup point')
          : (backupIsActiveDropoff
                ? (_firstNonEmpty([destinationPickup?['name']]) ??
                      'Backup pickup point')
                : 'Customer Home');
      final backupPickupId =
          hasBackupPickupPoint ? destinationPickup!['id'] : null;
      final backupPickupName = hasBackupPickupPoint
          ? _firstNonEmpty([destinationPickup!['name']])
          : null;
      final backupPickupAddress = hasBackupPickupPoint
          ? _firstNonEmpty([destinationPickup!['address_text']])
          : null;
      final backupPickupLat = hasBackupPickupPoint
          ? _toDouble(destinationPickup!['lat'])
          : null;
      final backupPickupLng = hasBackupPickupPoint
          ? _toDouble(destinationPickup!['lng'])
          : null;
      final backupPickupCity =
          hasBackupPickupPoint ? destinationPickup!['city']?.toString() : null;
      final backupPickupArea =
          hasBackupPickupPoint ? destinationPickup!['area']?.toString() : null;

      final mapped = {
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
            eventSuggestsFailure ||
            hasAutoAssignmentReason,
        'auto_assignment_reason': autoAssignmentReason,
        'pickup_source_type': pickupSourceType,
        'dropoff_type': dropoffType,
        'pickup_point_id': order['pickup_point_id'],
        'destination_pickup_point_id': order['destination_pickup_point_id'],
        'pickup_location_lat': order['pickup_location_lat'],
        'pickup_location_lng': order['pickup_location_lng'],
        'dropoff_location_lat': order['dropoff_location_lat'],
        'dropoff_location_lng': order['dropoff_location_lng'],
        'customer_lat': order['customer_lat'],
        'customer_lng': order['customer_lng'],
        'delivery_company_id': order['delivery_company_id'],
        'company_id': order['company_id'],
        'parcel_description': order['parcel_description'],
        'item_count': order['item_count'],
        'estimated_weight': order['estimated_weight'],
        'estimated_volume': order['estimated_volume'],
        'notes': order['notes'],
        'pickup_name': pickupName,
        'pickup_address': pickupAddress,
        'dropoff_name': dropoffType == 'pickup_point_specific'
            ? (_firstNonEmpty([destinationPickup?['name']]) ?? 'Pickup point')
            : activeDropoffName,
        'destination_type':
            dropoffType == 'pickup_point_specific' ? 'pickup_point' : 'home',
        'dropoff_lat': activeDropoffLat,
        'dropoff_lng': activeDropoffLng,
        'has_backup_pickup_point': hasBackupPickupPoint,
        'backup_pickup_point_id': backupPickupId,
        'backup_pickup_id': backupPickupId,
        'backup_pickup_point_name': backupPickupName,
        'backup_pickup_name': backupPickupName,
        'backup_pickup_point_address': backupPickupAddress,
        'backup_pickup_address': backupPickupAddress,
        'backup_pickup_point_lat': backupPickupLat,
        'backup_pickup_lat': backupPickupLat,
        'backup_pickup_point_lng': backupPickupLng,
        'backup_pickup_lng': backupPickupLng,
        'backup_pickup_point_city': backupPickupCity,
        'backup_pickup_city': backupPickupCity,
        'backup_pickup_point_area': backupPickupArea,
        'backup_pickup_area': backupPickupArea,
        'backup_pickup_is_active_dropoff': backupIsActiveDropoff,
        'merchant_name':
            _firstNonEmpty([merchant?['name']]) ?? 'Unknown merchant',
        'driver_id': hasLinkedDriverOnAssignment ? rawDriverId : null,
        'driver_name': resolvedDriverName,
        'driver_phone': resolvedDriverPhone,
        'vehicle_type': resolvedVehicleType,
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
        'dropoff_address': activeDropoffAddress ?? 'No dropoff address',
      };
      debugPrint(
        '[COMPANY_ORDER_MAP] ${mapped['tracking_code']} '
        'dropoff_type=$dropoffType '
        'destination_pickup_point_id=${order['destination_pickup_point_id']} '
        'backup=${mapped['backup_pickup_point_name']} '
        'backupLat=${mapped['backup_pickup_point_lat']} '
        'backupLng=${mapped['backup_pickup_point_lng']}',
      );
      return mapped;
    }).toList();
  }

  /// Merchant "specific pickup point" orders often leave `customer_address_text`
  /// null; the real destination is `destination_pickup_point_id`.
  String? _destinationPickupPointDropoffLabel(
    Map<String, dynamic>? pickupPoint,
  ) {
    if (pickupPoint == null) return null;
    final name = pickupPoint['name']?.toString().trim() ?? '';
    final addr = pickupPoint['address_text']?.toString().trim() ?? '';
    if (name.isNotEmpty && addr.isNotEmpty) {
      return '$name — $addr';
    }
    return _firstNonEmpty([name, addr]);
  }

  Future<List<Map<String, dynamic>>> _getCompanyOrderRows(
    List<String> companyIds,
  ) async {
    try {
      final orderRows = await _client
          .from('orders')
          .select(
            'id, tracking_code, merchant_id, branch_id, customer_profile_id, '
            'customer_name, customer_phone, customer_address_text, customer_lat, '
            'customer_lng, pickup_source_type, pickup_point_id, '
            'destination_pickup_point_id, dropoff_type, pickup_location_lat, '
            'pickup_location_lng, dropoff_location_lat, dropoff_location_lng, '
            'delivery_company_id, company_id, status, assignment_status, '
            'assigned_driver_id, assignment_failure_reason, parcel_description, '
            'item_count, estimated_weight, estimated_volume, notes, '
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
            'id, tracking_code, merchant_id, branch_id, customer_profile_id, '
            'customer_name, customer_phone, customer_address_text, customer_lat, '
            'customer_lng, pickup_source_type, pickup_point_id, '
            'destination_pickup_point_id, dropoff_type, pickup_location_lat, '
            'pickup_location_lng, dropoff_location_lat, dropoff_location_lng, '
            'delivery_company_id, company_id, status, parcel_description, '
            'item_count, estimated_weight, estimated_volume, notes, '
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
        final requestedDriverRows = List<Map<String, dynamic>>.from(
          await _client
              .from('drivers')
              .select(
                'id, profile_id, company_id, vehicle_type, verification_status',
              )
              .inFilter('profile_id', requestProfileIds),
        );

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
