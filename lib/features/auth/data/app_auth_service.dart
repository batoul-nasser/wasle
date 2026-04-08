import 'package:supabase_flutter/supabase_flutter.dart';

class AppAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> resolveInitialRoute() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return '/welcome';
    }

    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = (profile?['role']?.toString() ?? '').trim().toLowerCase();

      switch (role) {
        case 'merchant':
          return '/merchant';
        case 'driver':
          return '/driver';
        case 'customer':
          return '/customer';
        case 'company_admin':
        case 'delivery_company_admin':
          return '/company';
        case 'platform_admin':
        case 'admin':
          return '/admin';
        default:
          return '/welcome';
      }
    } catch (_) {
      return '/welcome';
    }
  }
}
