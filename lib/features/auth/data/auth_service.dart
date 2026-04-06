import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthFlowMode { login, driverSignup, companySignup }

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
    print('AUTH: getCurrentProfile user = ${user?.id}');

    if (user == null) return null;

    final result = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    print('AUTH: profile result = $result');
    return result;
  }

  Future<String?> getCurrentRole() async {
    final profile = await getCurrentProfile();
    return profile?['role']?.toString();
  }

  Future<String> resolveInitialRoute() async {
    print('AUTH: resolveInitialRoute started');

    final user = _client.auth.currentUser;
    print('AUTH: currentUser = ${user?.id}');

    if (user == null) {
      print('AUTH: no user, going to /');
      '/welcome';
    }

    final role = await getCurrentRole();
    print('AUTH: role = $role');

    switch (role) {
      case 'driver':
        return '/driver-dashboard';
      case 'company_admin':
        return '/company-dashboard';
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
      'profile_id': userId,
      'verification_status': 'pending',
      'city': city,
    });
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
}
