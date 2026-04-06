import '../../../core/services/supabase_service.dart';

class ProfileService {
  Future<String?> getUserRole(String userId) async {
    final data = await SupabaseService.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    return data?['role'] as String?;
  }

  Future<String?> getCurrentUserRole() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return null;
    return getUserRole(user.id);
  }

  Future<void> createProfile({
    required String id,
    required String fullName,
    required String email,
    required String phone,
    required String role,
  }) async {
    await SupabaseService.client.from('profiles').upsert({
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
    });
  }
}
