import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

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
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
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

  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
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

  Future<String?> checkDriverStatus() async {
    final user = _client.auth.currentUser;

    if (user == null) return null;

    final response = await _client
        .from('drivers')
        .select('verification_status')
        .eq('profile_id', user.id)
        .maybeSingle();

    if (response == null) return null;

    return response['verification_status'] as String?;
  }

  Future<List<Map<String, dynamic>>> getDriverRequestsForCurrentCompany() async {
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

  Future<void> createDriverProfile({
    required String userId,
    required String fullName,
    required String phone,
    required String city,
  }) async {
    await _client.from('profiles').upsert(
      {
        'id': userId,
        'full_name': fullName,
        'phone': phone,
        'role': 'driver',
      },
      onConflict: 'id',
    );

    await _client.from('drivers').upsert(
      {
        'profile_id': userId,
        'verification_status': 'pending',
      },
      onConflict: 'profile_id',
    );
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
    await _client.from('driver_company_requests').insert({
      'driver_profile_id': driverProfileId,
      'company_id': companyId,
    });
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

    await _client
        .from('drivers')
        .update({
          'verification_status': 'approved',
          'company_id': user.id,
        })
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
        .update({
          'verification_status': 'rejected',
        })
        .eq('profile_id', driverProfileId);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
Future<Map<String, dynamic>?> getDriverByProfileId(String profileId) async {
  final response = await _client
      .from('drivers')
      .select()
      .eq('profile_id', profileId)
      .maybeSingle();

  return response;
}

  User? get currentUser => _client.auth.currentUser;
}
