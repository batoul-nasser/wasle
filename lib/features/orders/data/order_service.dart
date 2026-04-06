import '../../../core/services/supabase_service.dart';

class OrdersService {
  Future<List<Map<String, dynamic>>> getOrders() async {
    final data = await SupabaseService.client.from('orders').select();
    return List<Map<String, dynamic>>.from(data);
  }
}
