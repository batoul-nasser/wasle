import '../../../core/services/supabase_service.dart';

class NotificationsService {
  Future<List<Map<String, dynamic>>> getMyNotifications(
    String profileId,
  ) async {
    final data = await SupabaseService.client
        .from('notifications')
        .select()
        .eq('profile_id', profileId);

    return List<Map<String, dynamic>>.from(data);
  }
}
