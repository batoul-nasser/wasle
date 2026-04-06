import '../../../core/services/supabase_service.dart';

class TrackingService {
  Future<Map<String, dynamic>?> getOrderTracking(String orderId) async {
    final data = await SupabaseService.client
        .from('order_tracking')
        .select()
        .eq('order_id', orderId)
        .maybeSingle();

    return data;
  }
}
