import 'package:supabase_flutter/supabase_flutter.dart';

/// Người yêu cầu của hồ sơ có thể là tài xế đã rời khỏi đơn. Không suy diễn
/// vai trò theo orders.driver_id và không mở quyền đọc toàn bộ users.
class SupportTicketContactsLoader {
  const SupportTicketContactsLoader(this.client);
  final SupabaseClient client;
  Future<List<Map<String, dynamic>>> enrich(
    List<Map<String, dynamic>> rows,
  ) async {
    final contacts = <String, Map<String, dynamic>>{};
    for (var offset = 0; offset < rows.length; offset += 200) {
      final ids = rows
          .skip(offset)
          .take(200)
          .map((row) => row['id'].toString())
          .toList();
      final data = await client.rpc(
        'get_support_ticket_contacts',
        params: {'p_ticket_ids': ids},
      );
      for (final contact in data as List) {
        final map = Map<String, dynamic>.from(contact as Map);
        contacts[map['ticket_id'].toString()] = map;
      }
    }
    return rows.map((row) {
      final contact = contacts[row['id'].toString()];
      return contact == null || contact['requester_id'] != row['requester_id']
          ? {...row, 'requester': null, 'requester_role': 'unknown'}
          : {
              ...row,
              ...contact,
              'requester': {
                'role': contact['requester_role'],
                'full_name': contact['requester_name'],
                'phone': contact['requester_phone'],
                'email': contact['requester_email'],
              },
            };
    }).toList();
  }
}
