import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/support_orders/data/support_order_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'fetches only this order proofs without signing the entire list',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode([
            {
              'stage': 'pickup',
              'storage_path': 'r2://media/orders/order-1/pickup',
              'captured_at': '2026-10-19T03:10:00Z',
            },
            {
              'stage': 'delivery',
              'storage_path': 'driver/order-1/delivery',
              'captured_at': '2026-10-19T04:20:00Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.dispose);

      final proofs = await SupabaseSupportOrderRepository(
        client,
      ).fetchDeliveryProofs('order-1');
      expect(proofs.map((proof) => proof.stage), ['pickup', 'delivery']);
      expect(
        proofs.first.capturedAt.toUtc(),
        DateTime.utc(2026, 10, 19, 3, 10),
      );
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/rest/v1/order_delivery_proofs');
      expect(requests.single.url.queryParameters['order_id'], 'eq.order-1');
      expect(
        requests.single.url.queryParameters['select'],
        'stage,storage_path,captured_at',
      );
    },
  );

  test(
    'metadata permission failures are not turned into an empty gallery',
    () async {
      final client = _client(
        (_) async => http.Response(
          '{"code":"42501","message":"permission denied"}',
          403,
          headers: {'content-type': 'application/json'},
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseSupportOrderRepository(client).fetchDeliveryProofs('order-1'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test(
    'signs an R2 proof with the session token and five minute expiry',
    () async {
      final client = _client((_) async => http.Response('[]', 200));
      addTearDown(client.dispose);
      final r2 = R2MediaClient(
        accessTokenProvider: () => 'staff-jwt',
        gatewayBaseUrl: 'https://r2.example.invalid',
        httpClient: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer staff-jwt');
          expect(jsonDecode(request.body), {
            'objectUri':
                'r2://media/orders/order-1/delivery-proofs/pickup/proof',
            'expiresIn': 300,
          });
          return http.Response(
            '{"downloadUrl":"https://private.example.invalid/signed"}',
            200,
          );
        }),
      );
      expect(
        await SupabaseSupportOrderRepository(
          client,
          r2Client: r2,
        ).resolveDeliveryProofUrl(
          'r2://media/orders/order-1/delivery-proofs/pickup/proof',
        ),
        'https://private.example.invalid/signed',
      );
    },
  );

  test('signs legacy proof paths in their original private bucket', () async {
    final client = _client((request) async {
      expect(
        request.url.path,
        '/storage/v1/object/sign/delivery-proofs/driver/order-1/pickup',
      );
      expect(jsonDecode(request.body)['expiresIn'], 300);
      return http.Response(
        '{"signedURL":"/object/sign/delivery-proofs/proof?token=signed"}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(client.dispose);
    final url = await SupabaseSupportOrderRepository(
      client,
    ).resolveDeliveryProofUrl('driver/order-1/pickup');
    expect(url, contains('token=signed'));
  });

  test(
    'keeps existing HTTPS URLs and rejects unsupported URI schemes',
    () async {
      final client = _client(
        (_) async => throw StateError('Unexpected request'),
      );
      addTearDown(client.dispose);
      final repository = SupabaseSupportOrderRepository(client);
      expect(
        await repository.resolveDeliveryProofUrl(
          'https://old.example.invalid/photo.jpg',
        ),
        'https://old.example.invalid/photo.jpg',
      );
      await expectLater(
        repository.resolveDeliveryProofUrl('javascript:alert(1)'),
        throwsFormatException,
      );
      await expectLater(
        repository.resolveDeliveryProofUrl(' '),
        throwsFormatException,
      );
    },
  );
}

SupabaseClient _client(Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient(
      'https://supabase.example.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        final response = await handler(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
