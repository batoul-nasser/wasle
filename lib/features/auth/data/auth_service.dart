import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthFlowMode {
  login,
  driverSignup,
  companySignup,
  customerSignup,
  merchantSignup,
}

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendOtp({
    required String email,
    required bool shouldCreateUser,
  }) async {
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: shouldCreateUser,
    );
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    return _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final result = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return result;
  }

  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    final result = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return result;
  }

  Future<Map<String, dynamic>?> getDriverByProfileId(String profileId) async {
    final result = await _client
        .from('drivers')
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();

    return result;
  }

  Future<Map<String, dynamic>?> getCompanyById(String companyId) async {
    final result = await _client
        .from('delivery_companies')
        .select()
        .eq('id', companyId)
        .maybeSingle();

    return result;
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
    return profile?['role']?.toString();
  }

  Future<String> resolveInitialRoute() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return '/welcome';
    }

    final role = await getCurrentRole();

    switch (role) {
      case 'driver':
        return '/driver-dashboard';
      case 'company_admin':
        return '/company-dashboard';
      case 'customer':
        return '/customer-dashboard';
      case 'merchant':
        return '/merchant-dashboard';
      default:
        return '/welcome';
    }
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
    });

    await _client.from('drivers').upsert({
      'id': userId,
      'profile_id': userId,
      'verification_status': 'pending',
    });

    await _client.from('driver_locations').upsert({
      'driver_id': userId,
      'city': city.isEmpty ? null : city,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'driver_id');
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
    });

    await _client.from('merchant_users').upsert({
      'id': userId,
      'profile_id': userId,
      'business_name': businessName,
    });
  }

  Future<List<Map<String, dynamic>>> getDriverDeliveries() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final driver = await _client
        .from('drivers')
        .select()
        .eq('profile_id', user.id)
        .maybeSingle();

    if (driver == null) return [];

    final driverId = driver['id'];

    final assignmentRows = await _client
        .from('assignments')
        .select('order_id')
        .eq('driver_id', driverId);

    if (assignmentRows.isEmpty) return [];

    final orderIds = assignmentRows
        .map((row) => row['order_id'])
        .where((id) => id != null)
        .toList();

    if (orderIds.isEmpty) return [];

    final orders = await _client
        .from('orders')
        .select()
        .inFilter('id', orderIds)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(orders);
  }

  Future<List<Map<String, dynamic>>> getMerchantOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final orders = await _client
        .from('orders')
        .select()
        .eq('merchant_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(orders);
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
}
