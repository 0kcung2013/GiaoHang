import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_mobile/core/models/review_model.dart';
import 'package:giaohang_mobile/core/services/review_service.dart';

void main() {
  test(
    'a read error never falls back to a review from the other direction',
    () async {
      var reads = 0;
      final client = await reviewTestClient((request) {
        reads++;
        if (reads == 1) {
          return response(request, {
            'code': '42501',
            'message': 'permission denied',
          }, 403);
        }
        return response(request, [
          reviewRow(direction: ReviewDirection.driverToCustomer),
        ]);
      });
      addTearDown(client.dispose);
      await expectLater(
        ReviewService(client: client).getReviewByOrderId('order-1'),
        throwsA(anything),
      );
      expect(reads, 1);
    },
  );

  for (final result in [
    null,
    {'ok': false},
    {'ok': true},
    {'review_id': 'review-1', 'direction': 'driver_to_customer', 'rating': 5},
    {'review_id': 'review-1', 'direction': 'customer_to_driver', 'rating': 2},
  ]) {
    test(
      'a malformed RPC response is not a successful review: $result',
      () async {
        final client = await reviewTestClient(
          (r) => response(r, r.url.path.contains('/rpc/') ? result : []),
        );
        addTearDown(client.dispose);
        await expectLater(
          ReviewService(
            client: client,
          ).submitCustomerDriverReview(orderId: 'order-1', rating: 5),
          throwsA(anything),
        );
      },
    );
  }

  test(
    'retry after an already committed review recovers only the authored direction',
    () async {
      var writes = 0;
      final client = await reviewTestClient((r) {
        if (r.url.path.contains('/rpc/')) {
          writes++;
          return response(r, {
            'code': 'P0001',
            'message': 'Order already reviewed by customer',
          }, 400);
        }
        expect(r.url.queryParameters['direction'], 'eq.customer_to_driver');
        return response(r, [reviewRow()]);
      });
      addTearDown(client.dispose);
      final result = await ReviewService(
        client: client,
      ).submitCustomerDriverReview(orderId: 'order-1', rating: 1);
      expect(result['review_id'], 'review-1');
      expect(result['rating'], 5);
      expect(result['already_reviewed'], isTrue);
      expect(writes, 1);
    },
  );

  test('normalizes comments and deduplicates only valid tags', () async {
    final client = await reviewTestClient((r) {
      expect(jsonDecode(r.body), {
        'p_order_id': 'order-1',
        'p_rating': 5,
        'p_comment': 'Cảm ơn',
        'p_tags': ['on_time', 'friendly'],
      });
      return response(r, {
        'review_id': 'review-1',
        'direction': 'customer_to_driver',
        'rating': 5,
      });
    });
    addTearDown(client.dispose);
    await ReviewService(client: client).submitCustomerDriverReview(
      orderId: 'order-1',
      rating: 5,
      comment: '  Cảm ơn  ',
      tags: ['on_time', 'friendly', 'on_time'],
    );
  });

  test(
    'rejects invalid ratings, tags, and overlong comments before network I/O',
    () async {
      var requests = 0;
      final client = await reviewTestClient((r) {
        requests++;
        return response(r, null);
      });
      addTearDown(client.dispose);
      final service = ReviewService(client: client);
      await expectLater(
        service.submitCustomerDriverReview(orderId: 'order-1', rating: 0),
        throwsA(anything),
      );
      await expectLater(
        service.submitCustomerDriverReview(orderId: 'order-1', rating: 6),
        throwsA(anything),
      );
      await expectLater(
        service.submitCustomerDriverReview(
          orderId: 'order-1',
          rating: 5,
          tags: ['unknown'],
        ),
        throwsA(anything),
      );
      await expectLater(
        service.submitDriverCustomerReview(
          orderId: 'order-1',
          rating: 5,
          comment: 'x' * 501,
        ),
        throwsA(anything),
      );
      expect(requests, 0);
    },
  );

  test(
    'the legacy createReview entry point respects driver-to-customer direction',
    () async {
      final client = await reviewTestClient((r) {
        expect(r.url.path, endsWith('/submit_driver_customer_review'));
        return response(r, {
          'review_id': 'review-1',
          'direction': 'driver_to_customer',
          'rating': 4,
        });
      });
      addTearDown(client.dispose);
      await ReviewService(client: client).createReview(
        ReviewModel(
          id: '',
          orderId: 'order-1',
          reviewerId: 'actor-1',
          driverId: 'driver-profile',
          direction: ReviewDirection.driverToCustomer,
          rating: 4,
          createdAt: DateTime.utc(2026),
        ),
      );
    },
  );

  test(
    'a lost response recovers a committed review without writing twice',
    () async {
      var writes = 0;
      final client = await reviewTestClient((r) {
        if (r.url.path.contains('/rpc/')) {
          writes++;
          throw http.ClientException('connection lost');
        }
        expect(r.url.queryParameters['reviewer_id'], 'eq.actor-1');
        return response(r, [reviewRow()]);
      });
      addTearDown(client.dispose);
      final receipt = await ReviewService(
        client: client,
      ).submitCustomerDriverReview(orderId: 'order-1', rating: 5);
      expect(receipt['already_reviewed'], isTrue);
      expect(writes, 1);
    },
  );

  test('a readback for another author cannot confirm submission', () async {
    final client = await reviewTestClient(
      (r) => r.url.path.contains('/rpc/')
          ? response(r, {'message': 'internal SQL detail'}, 400)
          : response(r, [
              {...reviewRow(), 'reviewer_id': 'other-user'},
            ]),
    );
    addTearDown(client.dispose);
    await expectLater(
      ReviewService(
        client: client,
      ).submitCustomerDriverReview(orderId: 'order-1', rating: 5),
      throwsA(
        isA<ReviewException>().having(
          (e) => e.message,
          'safe message',
          ReviewService.submitError,
        ),
      ),
    );
  });

  test(
    'signing out while submitting cannot confirm success for the next session',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<http.Request>();
      var reads = 0;
      final client = await reviewTestClient((r) {
        if (!r.url.path.contains('/rpc/')) {
          reads++;
          return response(r, []);
        }
        started.complete(r);
        return pending.future;
      });
      addTearDown(client.dispose);
      final submission = ReviewService(
        client: client,
      ).submitCustomerDriverReview(orderId: 'order-1', rating: 5);
      final expectation = expectLater(
        submission,
        throwsA(isA<ReviewException>()),
      );
      final request = await started.future;
      await client.auth.signOut(scope: SignOutScope.local);
      pending.complete(
        response(request, {
          'review_id': 'review-1',
          'direction': 'customer_to_driver',
          'rating': 5,
        }),
      );
      await expectation;
      expect(reads, 0);
    },
  );

  test('driver tags are validated independently from customer tags', () async {
    var requests = 0;
    final client = await reviewTestClient((r) {
      requests++;
      return response(r, null);
    });
    addTearDown(client.dispose);
    await expectLater(
      ReviewService(client: client).submitDriverCustomerReview(
        orderId: 'order-1',
        rating: 5,
        tags: ['bad_attitude'],
      ),
      throwsA(isA<ReviewException>()),
    );
    expect(requests, 0);
  });
}

http.Response response(http.Request r, Object? data, [int status = 200]) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json'},
      request: r,
    );

Future<SupabaseClient> reviewTestClient(
  FutureOr<http.Response> Function(http.Request) handle,
) async {
  final client = SupabaseClient(
    'https://supabase.example.invalid',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((r) async {
      if (r.url.path.startsWith('/auth/')) {
        return response(r, {
          'access_token': 'test-access-token',
          'refresh_token': 'test-refresh-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 'actor-1',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'test@example.invalid',
            'created_at': '2026-10-20T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
          },
        });
      }
      return handle(r);
    }),
  );
  await client.auth.signInWithPassword(
    email: 'test@example.invalid',
    password: 'test-password',
  );
  return client;
}

Map<String, dynamic> reviewRow({
  String direction = ReviewDirection.customerToDriver,
}) => {
  'id': 'review-1',
  'order_id': 'order-1',
  'reviewer_id': 'actor-1',
  'driver_id': 'driver-profile',
  'reviewee_id': 'other-1',
  'direction': direction,
  'rating': 5,
  'comment': 'Cảm ơn',
  'tags': ['on_time'],
  'created_at': '2026-10-20T00:00:00Z',
};
