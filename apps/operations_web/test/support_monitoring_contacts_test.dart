import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'case requester remains former driver independently of current order owner',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          final Object data;
          if (request.url.path.endsWith('/get_support_ticket_contacts')) {
            expect(jsonDecode(request.body), {
              'p_ticket_ids': ['case'],
            });
            data = [
              {
                'ticket_id': 'case',
                'requester_id': 'old-driver',
                'requester_role': 'driver',
                'requester_name': 'Tài xế trước',
                'requester_phone': '0901234567',
                'requester_email': 'old@example.invalid',
              },
            ];
          } else if (request.url.path.endsWith('/support_tickets')) {
            data = {
              'id': 'case',
              'requester_id': 'old-driver',
              'order_id': 'order',
              'subject': 'Giám sát: thu hồi phân công',
              'requester': null,
              'status': 'open',
              'priority': 'high',
              'last_message_role': 'system',
            };
          } else {
            throw StateError('Unexpected ${request.url.path}');
          }
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final ticket = await SupabaseSupportTicketRepository(
        client,
      ).fetchTicket('case');
      expect(ticket.isDriverRequester, isTrue);
      expect(ticket.requesterName, 'Tài xế trước');
      expect(ticket.requesterPhone, '0901234567');
      expect(ticket.requesterEmail, 'old@example.invalid');
      expect(ticket.needsReply, isTrue);
    },
  );
}
