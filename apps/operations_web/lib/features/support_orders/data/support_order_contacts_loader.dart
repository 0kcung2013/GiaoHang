import 'package:supabase_flutter/supabase_flutter.dart';

/// Chỉ đọc các hồ sơ liên hệ thuộc đơn/hồ sơ đang xử lý bằng RPC dành cho staff.
class SupabaseSupportOrderContactsLoader {
  const SupabaseSupportOrderContactsLoader(this._client);
  final SupabaseClient _client;

  Future<SupportOrderContacts> fetch(
    List<String> orderIds, {
    String? reportId,
  }) async {
    if (orderIds.isEmpty) return const SupportOrderContacts.empty();
    final result = await _client.rpc(
      'get_support_order_contacts',
      params: {'p_order_ids': orderIds, 'p_report_id': ?reportId},
    );
    return SupportOrderContacts.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }
}

class SupportOrderContacts {
  const SupportOrderContacts.empty() : _orders = const {}, reporter = null;
  const SupportOrderContacts._(this._orders, this.reporter);

  final Map<String, Map<String, dynamic>> _orders;
  final Map<String, dynamic>? reporter;

  factory SupportOrderContacts.fromJson(Map<String, dynamic> json) =>
      SupportOrderContacts._(
        {
          for (final row in (json['orders'] as List? ?? const []))
            (row as Map)['order_id'].toString(): Map<String, dynamic>.from(row),
        },
        json['reporter'] is Map
            ? Map<String, dynamic>.from(json['reporter'] as Map)
            : null,
      );

  Map<String, dynamic> enrichOrder(Map<String, dynamic> row) {
    final contacts = _orders[row['id']?.toString()];
    return {
      ...row,
      if (contacts != null) ...{
        // Không ghép liên hệ của tài xế mới vào snapshot cũ khi đang đổi phân công.
        'customer': contacts['customer_id'] == row['customer_id']
            ? contacts['customer']
            : null,
        'driver': contacts['driver_id'] == row['driver_id']
            ? contacts['driver']
            : null,
      },
    };
  }
}
