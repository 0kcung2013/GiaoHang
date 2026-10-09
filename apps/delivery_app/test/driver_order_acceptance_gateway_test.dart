import 'dart:convert';

import 'package:delivery_app/core/services/driver_order_acceptance_gateway.dart';
import 'package:delivery_app/core/services/free_pick_service.dart';
import 'package:delivery_app/core/services/order_assignment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final expired in [true, false]) {
    test(
      'normal acceptance ${expired ? 'reports expiry' : 'commits through the gateway'}',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: MockClient((request) async {
            requests.add(request);
            expect(request.url.path, '/functions/v1/accept-driver-order');
            expect(jsonDecode(request.body), {
              'order_id': 'order-1',
              'free_pick': false,
              'existing_only': false,
            });
            return http.Response(
              expired
                  ? '{"error":"OFFER_EXPIRED"}'
                  : '[{"order_id":"order-1","customer_id":"","tracking_code":"GH-1","estimated_delivery_at":"2026-10-08T12:00:00Z"}]',
              expired ? 409 : 200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        await client.auth.setInitialSession(
          jsonEncode({
            'access_token': 'test-token',
            'token_type': 'bearer',
            'user': {
              'id': 'driver-1',
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
        );
        final accept = OrderAssignmentService(
          client: client,
        ).acceptOrder('order-1', 'driver-1');
        if (expired) {
          await expectLater(
            accept,
            throwsA(
              predicate(
                (error) =>
                    error.toString().contains('Lời mời nhận đơn đã hết hạn'),
              ),
            ),
          );
        } else {
          await accept;
        }
        expect(requests, hasLength(1));
      },
    );
  }

  test(
    'FreePick production path uses server acceptance with deadline',
    () async {
      Map<String, dynamic>? body;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/functions/v1/accept-driver-order');
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode([
              {
                'order_id': 'order-1',
                'customer_id': '',
                'tracking_code': 'GH-1',
                'estimated_delivery_at': '2026-10-02T14:00:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await FreePickService(
        client: client,
      ).claimOrder('order-1');
      expect(body, {
        'order_id': 'order-1',
        'free_pick': true,
        'existing_only': false,
      });
      expect(result.trackingCode, 'GH-1');
    },
  );

  test('server rejection retains the existing acceptance error code', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":"DRIVER_ACCEPTANCE_LOCKED"}',
          409,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      acceptDriverOrderWithDeadline(client, 'order-1'),
      throwsA(
        predicate(
          (error) => error.toString().contains('DRIVER_ACCEPTANCE_LOCKED'),
        ),
      ),
    );
  });
}
