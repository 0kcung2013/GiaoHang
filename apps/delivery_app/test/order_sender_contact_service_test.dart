import 'dart:convert';

import 'package:delivery_app/core/services/customer_order_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'loads the assigned order sender contact through the secured RPC',
    () async {
      late http.Request capturedRequest;
      final httpClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode([
            {'contact_name': 'Nguyễn Văn An', 'contact_phone': '0900000000'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        httpClient: httpClient,
      );
      addTearDown(client.dispose);
      final service = CustomerOrderService(client: client);

      final contact = await service.getOrderSenderContact('order-1');

      expect(
        capturedRequest.url.path,
        endsWith('/rest/v1/rpc/get_order_sender_contact'),
      );
      expect(jsonDecode(capturedRequest.body), {'p_order_id': 'order-1'});
      expect(contact, isNotNull);
      expect(contact!.name, 'Nguyễn Văn An');
      expect(contact.phone, '0900000000');
    },
  );

  test('returns null when the RPC hides an unauthorized order', () async {
    final client = SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final contact = await CustomerOrderService(
      client: client,
    ).getOrderSenderContact('other-order');

    expect(contact, isNull);
  });
}
