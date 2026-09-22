import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_order.dart';

abstract interface class SupportOrderRepository {
  Future<List<SupportOrder>> fetchOrders({String trackingCode = ''});

  Future<List<SupportOrderStatusLog>> fetchStatusLogs(String orderId);
}

class SupabaseSupportOrderRepository implements SupportOrderRepository {
  SupabaseSupportOrderRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SupportOrder>> fetchOrders({String trackingCode = ''}) async {
    var query = _client.from('orders').select('''
      id,
      customer_id,
      driver_id,
      tracking_code,
      status,
      pickup_address,
      delivery_address,
      total_price,
      delivery_fee,
      recipient_name,
      recipient_phone,
      item_name,
      note,
      payment_method,
      created_at,
      updated_at
    ''');
    final normalizedCode = trackingCode.trim();
    if (normalizedCode.isNotEmpty) {
      query = query.ilike('tracking_code', '%$normalizedCode%');
    }
    final rows = await query.order('created_at', ascending: false).limit(200);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(SupportOrder.fromJson).toList();
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
