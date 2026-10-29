import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support_orders/data/support_order_contacts_loader.dart';
import '../../support_orders/data/support_order_selection.dart';
import '../../support_orders/models/support_order.dart';

abstract interface class AdminOrderRepository {
  Future<List<SupportOrder>> fetchPage({
    String query = '',
    String? status,
    int offset = 0,
  });
  Future<SupportOrder> fetchOrder(String id);
}

class SupabaseAdminOrderRepository implements AdminOrderRepository {
  SupabaseAdminOrderRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 50;
  @override
  Future<List<SupportOrder>> fetchPage({
    String query = '',
    String? status,
    int offset = 0,
  }) async {
    var request = client
        .from('orders')
        .select(
          'id,tracking_code,status,pickup_address,delivery_address,created_at,updated_at,total_price,delivery_fee',
        );
    if (status != null) request = request.eq('status', status);
    final search = query
        .trim()
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    if (search.isNotEmpty) {
      request = request.ilike('tracking_code', '%$search%');
    }
    final rows = await request
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + pageSize)
        .timeout(const Duration(seconds: 15));
    return rows.map(SupportOrder.fromJson).toList();
  }

  @override
  Future<SupportOrder> fetchOrder(String id) async {
    final row = await client
        .from('orders')
        .select(supportOrderSelection)
        .eq('id', id)
        .single()
        .timeout(const Duration(seconds: 15));
    final contacts = await SupabaseSupportOrderContactsLoader(
      client,
    ).fetch([id]);
    return SupportOrder.fromJson(contacts.enrichOrder(row));
  }
}
