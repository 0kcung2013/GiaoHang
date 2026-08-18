import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportOrderReturnRepository {
  SupportOrderReturnRepository(this._client);

  final SupabaseClient _client;

  Future<OrderReturn?> fetchForOrder(String orderId) async {
    final row = await _client
        .from('order_returns')
        .select()
        .eq('order_id', orderId)
        .maybeSingle();
    return row == null ? null : OrderReturn.fromJson(row);
  }

  Stream<OrderReturn?> watchForOrder(String orderId) => _client
      .from('order_returns')
      .stream(primaryKey: ['id'])
      .eq('order_id', orderId)
      .map((rows) => rows.isEmpty ? null : OrderReturn.fromJson(rows.first));

  Future<OrderReturn> approve(ReturnApprovalDraft draft) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'support_approve_return',
      params: draft.toRpcParams(),
    );
    return OrderReturn.fromJson(row);
  }
}
