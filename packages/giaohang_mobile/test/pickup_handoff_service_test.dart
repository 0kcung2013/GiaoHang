import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/order_handoff/data/pickup_handoff_service.dart';
import 'package:giaohang_mobile/features/order_handoff/pickup_handoff_strings.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('creator code preserves leading zeros and server expiry', () async {
    final client = _client((request) {
      expect(request.url.path, endsWith('/rpc/get_customer_pickup_code'));
      expect(jsonDecode(request.body), {'p_order_id': 'order'});
      return {
        'code': '0012',
        'driver_id': 'driver',
        'server_now': '2026-10-19T08:00:00Z',
        'expires_at': '2026-10-19T08:15:00Z',
      };
    });
    addTearDown(client.dispose);
    final code = await PickupHandoffService(
      client: client,
    ).getCustomerCode('order');
    expect(code.code, '0012');
    expect(
      code.expiresAt!.difference(code.serverNow),
      const Duration(minutes: 15),
    );
  });

  test('driver submits code to the atomic confirmation RPC', () async {
    final client = _client((request) {
      expect(request.url.path, endsWith('/rpc/confirm_driver_pickup_code'));
      expect(jsonDecode(request.body), {
        'p_order_id': 'order',
        'p_code': '0012',
      });
      return {
        'success': true,
        'new_status': 'delivering',
        'confirmed_at': '2026-10-19T08:00:00Z',
      };
    });
    addTearDown(client.dispose);
    await PickupHandoffService(
      client: client,
    ).confirmPickup(orderId: 'order', code: '0012');
  });

  for (final error in {
    'PICKUP_CODE_INVALID': PickupHandoffStrings.codeInvalid,
    'PICKUP_CODE_LOCKED': PickupHandoffStrings.codeLocked,
    'PICKUP_CODE_EXPIRED': PickupHandoffStrings.codeExpired,
  }.entries) {
    test(
      'server domain error ${error.key} never reports custody success',
      () async {
        final client = _client((_) => {'success': false, 'error': error.key});
        addTearDown(client.dispose);
        await expectLater(
          PickupHandoffService(
            client: client,
          ).confirmPickup(orderId: 'order', code: '0012'),
          throwsA(
            isA<PickupHandoffException>().having(
              (e) => e.message,
              'message',
              error.value,
            ),
          ),
        );
      },
    );
  }

  test(
    'malformed input is rejected before RPC; incomplete receipts fail closed',
    () async {
      var calls = 0;
      final client = _client((_) {
        calls++;
        return {'success': true};
      });
      addTearDown(client.dispose);
      final service = PickupHandoffService(client: client);
      await expectLater(
        service.confirmPickup(orderId: 'order', code: '123'),
        throwsA(isA<PickupHandoffException>()),
      );
      expect(calls, 0);
      await expectLater(
        service.confirmPickup(orderId: 'order', code: '1234'),
        throwsA(isA<PickupHandoffException>()),
      );
      expect(calls, 1);
    },
  );
}

SupabaseClient _client(Map<String, dynamic> Function(http.Request) response) =>
    SupabaseClient(
      'http://localhost:54321',
      'test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(response(request)),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
