import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'general support queries the signed-in requester and writes null order',
    () async {
      var reads = 0;
      var writes = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          Object response;
          if (request.url.path.endsWith('/auth/v1/token')) {
            response = {
              'access_token': 'test-access-token',
              'refresh_token': 'test-refresh-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'requester',
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'user@example.invalid',
                'created_at': '2026-10-18T00:00:00Z',
                'app_metadata': <String, dynamic>{},
                'user_metadata': <String, dynamic>{},
              },
            };
          } else if (request.url.path.endsWith('/support_tickets')) {
            final row = {
              'id': 'general',
              'requester_id': 'requester',
              'order_id': null,
              'subject': 'Trao đổi với CSKH',
              'message': 'Chào',
              'status': 'open',
            };
            if (request.method == 'GET') {
              reads++;
              expect(
                request.url.queryParameters['requester_id'],
                'eq.requester',
              );
              expect(request.url.queryParameters['order_id'], 'is.null');
              response = [row];
            } else {
              writes++;
              final payload = jsonDecode(request.body) as Map;
              expect(payload['requester_id'], 'requester');
              expect(payload['order_id'], isNull);
              expect(payload['message'], 'Chào');
              response = row;
            }
          } else {
            throw StateError('Unexpected request: ${request.url.path}');
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'user@example.invalid',
        password: 'fake-password',
      );
      final repository = SupabaseParticipantSupportTicketRepository(
        client: client,
      );
      expect((await repository.fetchGeneralTickets()).single.orderId, isNull);
      final created = await repository.create(
        const SupportTicketDraft(
          requesterId: 'requester',
          subject: 'Trao đổi với CSKH',
          message: 'Chào',
          priority: SupportTicketPriority.normal,
        ),
      );
      expect(created.orderId, isNull);
      expect(reads, 1);
      expect(writes, 1);
    },
  );
}
