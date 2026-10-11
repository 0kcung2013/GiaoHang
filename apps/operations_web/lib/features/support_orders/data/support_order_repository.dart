import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_order.dart';
import 'support_order_selection.dart';
import 'support_order_contacts_loader.dart';

abstract interface class SupportOrderRepository {
  Future<List<SupportOrder>> fetchOrders({String trackingCode = ''});

  Future<List<SupportOrderStatusLog>> fetchStatusLogs(String orderId);
}

class SupabaseSupportOrderRepository implements SupportOrderRepository {
  SupabaseSupportOrderRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SupportOrder>> fetchOrders({String trackingCode = ''}) async {
    var query = _client.from('orders').select(supportOrderSelection);
    final normalizedCode = trackingCode.trim();
    if (normalizedCode.isNotEmpty) {
      query = query.ilike('tracking_code', '%$normalizedCode%');
    }
    final rows = await query.order('created_at', ascending: false).limit(200);
    final orders = List<Map<String, dynamic>>.from(rows);
    final contacts = await SupabaseSupportOrderContactsLoader(
      _client,
    ).fetch(orders.map((row) => row['id'].toString()).toList());
    return orders.map(contacts.enrichOrder).map(SupportOrder.fromJson).toList();
  }

  @override
  Future<List<SupportOrderStatusLog>> fetchStatusLogs(String orderId) async {
    final rows = await _client
        .from('order_status_logs')
        .select('status, title, description, created_at')
        .eq('order_id', orderId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(SupportOrderStatusLog.fromJson).toList();
  }
}
