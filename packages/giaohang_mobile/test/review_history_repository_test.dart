import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_mobile/core/models/review_model.dart';
import 'package:giaohang_mobile/core/services/review_service.dart';
import 'package:giaohang_mobile/features/reviews/history/data/review_history_repository.dart';

import 'review_service_test.dart' show reviewTestClient, response, reviewRow;

void main() {
  test(
    'reads only authored customer reviews with server filtering and stable paging',
    () async {
      late http.Request request;
      final client = await reviewTestClient((r) {
        request = r;
        return response(r, [
          {
            ...reviewRow(),
            'order': {
              'tracking_code': 'GH00001',
              'delivery_address': '12 Nguyễn Huệ',
            },
          },
        ]);
      });
      addTearDown(client.dispose);
      final rows = await SupabaseReviewHistoryRepository(
        client,
      ).fetch(rating: 5, offset: 20);
      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/reviews'));
      expect(request.url.queryParameters['reviewer_id'], 'eq.actor-1');
      expect(request.url.queryParameters['direction'], 'eq.customer_to_driver');
      expect(request.url.queryParameters['rating'], 'eq.5');
      expect(
        request.url.queryParameters['order'],
        'created_at.desc.nullslast,id.desc.nullslast',
      );
      expect(request.url.queryParameters['offset'], '20');
      expect(request.url.queryParameters['limit'], '20');
      expect(
        request.url.queryParameters['select'],
        contains('reviews_order_id_fkey'),
      );
      expect(rows.single.trackingCode, 'GH00001');
      expect(rows.single.deliveryAddress, '12 Nguyễn Huệ');
      expect(rows.single.toJson()['rating'], 5);
    },
  );

  test('a missing order relation preserves the review', () async {
    final client = await reviewTestClient((r) {
      expect(r.url.queryParameters.containsKey('rating'), isFalse);
      return response(r, [
        {...reviewRow(), 'order': null},
      ]);
    });
    addTearDown(client.dispose);
    final rows = await SupabaseReviewHistoryRepository(client).fetch();
    expect(rows.single.review.comment, 'Cảm ơn');
    expect(rows.single.trackingCode, isNull);
  });

  for (final invalid in [
    {'reviewer_id': 'another-actor'},
    {'direction': ReviewDirection.driverToCustomer},
    {'rating': 0},
  ]) {
    test(
      'rejects a response outside the authored history contract: $invalid',
      () async {
        final client = await reviewTestClient(
          (r) => response(r, [
            {...reviewRow(), ...invalid},
          ]),
        );
        addTearDown(client.dispose);
        await expectLater(
          SupabaseReviewHistoryRepository(client).fetch(),
          throwsA(isA<ReviewException>()),
        );
      },
    );
  }

  test('discards an in-flight response after sign-out', () async {
    final pending = Completer<http.Response>();
    final started = Completer<http.Request>();
    final client = await reviewTestClient((r) {
      started.complete(r);
      return pending.future;
    });
    addTearDown(client.dispose);
    final result = SupabaseReviewHistoryRepository(client).fetch();
    final expectation = expectLater(result, throwsA(isA<ReviewException>()));
    final request = await started.future;
    await client.auth.signOut(scope: SignOutScope.local);
    pending.complete(response(request, [reviewRow()]));
    await expectation;
  });
}
