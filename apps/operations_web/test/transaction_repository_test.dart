import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/support_transactions/data/transaction_repository.dart';
import 'package:operations_web/features/support_transactions/models/support_transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/transaction_test_repository.dart';

void main() {
  test(
    'sends server-side search, UTC date bounds and source-aware cursor',
    () async {
      final from = DateTime(2026, 10, 1), to = DateTime(2026, 11, 1);
      final before = transactionFixture(id: 'uuid');
      final client = _client((r) {
        expect(r.url.path, '/rest/v1/rpc/list_support_transactions');
        expect(jsonDecode(r.body), {
          'p_group': 'payments',
          'p_search': '%test_',
          'p_status': 'pending',
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
          'p_before_created_at': before.createdAt.toUtc().toIso8601String(),
          'p_before_key': 'driver:uuid',
          'p_limit': 30,
        });
        return {
          'rows': [],
          'has_more': false,
          'server_now': '2026-10-20T00:00:00Z',
        };
      });
      addTearDown(client.dispose);
      final page = await SupabaseTransactionRepository(client).fetch(
        group: TransactionGroup.payments,
        search: ' %test_ ',
        status: 'pending',
        from: from,
        to: to,
        before: before,
      );
      expect(page.hasMore, isFalse);
    },
  );
  test('rejects an empty page claiming more data instead of looping', () async {
    final client = _client(
      (r) => {
        'rows': [],
        'has_more': true,
        'server_now': '2026-10-20T00:00:00Z',
      },
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseTransactionRepository(
        client,
      ).fetch(group: TransactionGroup.topups),
      throwsFormatException,
    );
  });
  test(
    'request lookup includes the stable transaction marker for a topup without order',
    () async {
      final tx = transactionFixture();
      final client = _client((r) {
        expect(r.url.path, '/rest/v1/support_tickets');
        expect(
          r.url.queryParameters['or'],
          '(message.like.%${tx.requestMarker}%)',
        );
        return [
          {'id': 'ticket', 'subject': 'Kiểm tra nạp tiền', 'status': 'open'},
        ];
      });
      addTearDown(client.dispose);
      expect(
        (await SupabaseTransactionRepository(
          client,
        ).fetchRequests(tx)).single.id,
        'ticket',
      );
    },
  );
  test(
    'overdue payment remains pending and does not fabricate completion time',
    () {
      final tx = SupportTransaction.fromJson({
        'id': '1',
        'source': 'vnpay',
        'kind': 'order_payment',
        'status': 'pending',
        'amount': 50000,
        'user_id': 'user',
        'created_at': '2026-10-19T01:00:00Z',
        'expires_at': '2026-10-19T01:15:00Z',
      });
      expect(tx.isOverdue(DateTime.utc(2026, 10, 20)), isTrue);
      expect(tx.status, 'pending');
      expect(tx.completedAt, isNull);
    },
  );
}

SupabaseClient _client(Object Function(http.Request) response) =>
    SupabaseClient(
      'https://supabase.example.invalid',
      'test-key',
      httpClient: MockClient(
        (r) async => http.Response(
          jsonEncode(response(r)),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
