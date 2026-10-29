import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/data/customer_payment_repository.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/models/customer_payment.dart';

import 'helpers/customer_payment_fixtures.dart';
import 'review_service_test.dart' show reviewTestClient, response;

void main() {
  final range = (start: DateTime(2026, 10), end: DateTime(2026, 11));
  Map<String, dynamic> row(String id, CustomerPaymentMethod method) => {
    ...paymentFixture(id: id, method: method).toJson(),
    'customer_id': 'actor-1',
  };

  test(
    'reads both owned sources completely with Vietnam boundaries and keyset paging',
    () async {
      final requests = <http.Request>[];
      var walletPages = 0;
      final client = await reviewTestClient((request) {
        requests.add(request);
        if (request.url.path.endsWith('/customer_wallet_transactions')) {
          walletPages++;
          return response(
            request,
            walletPages == 1
                ? List.generate(
                    100,
                    (index) => row(
                      'wallet-${100 - index}',
                      CustomerPaymentMethod.wallet,
                    ),
                  )
                : [row('wallet-0', CustomerPaymentMethod.wallet)],
          );
        }
        return response(request, [row('vnpay-1', CustomerPaymentMethod.vnpay)]);
      });
      addTearDown(client.dispose);
      final payments = await SupabaseCustomerPaymentRepository(
        client,
      ).fetch(range);
      expect(payments, hasLength(102));
      expect(requests, hasLength(3));
      for (final request in requests) {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['customer_id'], 'eq.actor-1');
        expect(request.url.queryParametersAll['created_at'], [
          'gte.2026-09-30T17:00:00.000Z',
          'lt.2026-10-31T17:00:00.000Z',
        ]);
        expect(request.url.queryParameters['limit'], '100');
      }
      final walletRequests = requests
          .where(
            (request) =>
                request.url.path.endsWith('/customer_wallet_transactions'),
          )
          .toList();
      expect(
        walletRequests.first.url.queryParameters['transaction_type'],
        'eq.delivery_fee_payment',
      );
      expect(
        walletRequests.last.url.queryParameters['or'],
        contains('id.lt.wallet-1'),
      );
      expect(
        requests
            .firstWhere(
              (request) => request.url.path.endsWith('/order_payment_sessions'),
            )
            .url
            .queryParameters['provider'],
        'eq.vnpay',
      );
    },
  );

  test(
    'a failed source rejects the whole snapshot, without partial totals',
    () async {
      final client = await reviewTestClient(
        (request) => request.url.path.endsWith('/order_payment_sessions')
            ? response(request, {'message': 'denied', 'code': '42501'}, 403)
            : response(request, [
                row('wallet-1', CustomerPaymentMethod.wallet),
              ]),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseCustomerPaymentRepository(client).fetch(range),
        throwsA(anything),
      );
    },
  );

  test('rejects rows belonging to another customer', () async {
    final client = await reviewTestClient(
      (request) => response(
        request,
        request.url.path.endsWith('/customer_wallet_transactions')
            ? [
                {
                  ...row('wallet-1', CustomerPaymentMethod.wallet),
                  'customer_id': 'other',
                },
              ]
            : [],
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseCustomerPaymentRepository(client).fetch(range),
      throwsA(anything),
    );
  });

  test('sign-out during loading discards both sources', () async {
    final pending = Completer<http.Response>();
    final started = Completer<http.Request>();
    final client = await reviewTestClient((request) {
      if (request.url.path.endsWith('/order_payment_sessions')) {
        return response(request, []);
      }
      started.complete(request);
      return pending.future;
    });
    addTearDown(client.dispose);
    final fetch = SupabaseCustomerPaymentRepository(client).fetch(range);
    final expectation = expectLater(fetch, throwsA(anything));
    final request = await started.future;
    await client.auth.signOut(scope: SignOutScope.local);
    pending.complete(
      response(request, [row('wallet-1', CustomerPaymentMethod.wallet)]),
    );
    await expectation;
  });
}
