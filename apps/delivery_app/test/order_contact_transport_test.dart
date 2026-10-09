import 'dart:convert';

import 'package:delivery_app/features/order_contact/services/order_contact_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'loads the latest 200 messages and presents them oldest to newest',
    () async {
      final rows = List.generate(
        201,
        (index) => {
          'id': 'message-$index',
          'order_id': 'order-1',
          'sender_id': 'customer-1',
          'client_message_id': 'client-$index',
          'message_type': 'text',
          'body': 'Tin $index',
          'created_at': DateTime.utc(
            2026,
            10,
            8,
            14,
          ).add(Duration(minutes: index)).toIso8601String(),
        },
      );
      Uri? messagesRequest;
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/orders')) {
            return http.Response(
              '{"status":"picking_up"}',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          messagesRequest = request.url;
          final descending =
              request.url.queryParameters['order']?.startsWith(
                'created_at.desc',
              ) ==
              true;
          final ordered = descending ? rows.reversed : rows;
          final limit = int.parse(request.url.queryParameters['limit']!);
          return http.Response(
            jsonEncode(ordered.take(limit).toList()),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final transport = SupabaseOrderContactTransport(
        client: client,
        orderId: 'order-1',
        currentUserId: 'driver-1',
      );

      final conversation = await transport.loadConversation();

      expect(messagesRequest!.queryParameters['order_id'], 'eq.order-1');
      expect(
        messagesRequest!.queryParameters['order'],
        'created_at.desc.nullslast,id.desc.nullslast',
      );
      expect(conversation.messages, hasLength(200));
      expect(conversation.messages.first.id, 'message-1');
      expect(conversation.messages.last.id, 'message-200');
      expect(conversation.canSend, isTrue);
    },
  );
}
