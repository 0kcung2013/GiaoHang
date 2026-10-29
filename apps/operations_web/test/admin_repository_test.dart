import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:operations_web/features/admin/data/admin_repository.dart';
import 'package:operations_web/features/admin/data/admin_order_repository.dart';
import 'package:operations_web/features/admin/models/admin_snapshot.dart';

void main() {
  test(
    'metrics use independent server counts and preserve unavailable as null',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/rpc/admin_dashboard_stats')) {
            expect(r.method, 'POST');
            return http.Response(
              jsonEncode({
                'total_drivers': 4,
                'total_customers': 2,
                'pending_drivers': 1,
              }),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          if (r.url.path.endsWith('/rpc/disabled_account_count')) {
            return http.Response(
              '{"message":"permission denied","code":"42501"}',
              403,
              request: r,
            );
          }
          expect(r.method, 'HEAD');
          expect(r.url.path.endsWith('/drivers'), isFalse);
          expect(r.url.path.endsWith('/users'), isFalse);

          return http.Response(
            '',
            200,
            request: r,
            headers: {
              'content-range': '*/123',
              'content-type': 'application/json',
            },
          );
        }),
      );
      addTearDown(client.dispose);
      final snapshot = await SupabaseAdminRepository(client).fetchSnapshot();
      expect(requests.length, 7);
      expect(snapshot[AdminMetric.orders], 123);
      expect(snapshot[AdminMetric.drivers], 4);
      expect(snapshot[AdminMetric.customers], 2);
      expect(snapshot[AdminMetric.kyc], 1);
      expect(snapshot[AdminMetric.disabledAccounts], isNull);
      expect(snapshot.hasErrors, isTrue);
      expect(
        requests
            .firstWhere(
              (r) => r.url.path.endsWith('/driver_profile_change_requests'),
            )
            .url
            .queryParameters['status'],
        'in.("pending","applying")',
      );
    },
  );
  test(
    'restricted metrics remain unknown when the admin RPC is unavailable',
    () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (r) async => r.method == 'POST'
              ? http.Response(
                  '{"message":"denied","code":"42501"}',
                  403,
                  request: r,
                )
              : http.Response(
                  '',
                  200,
                  request: r,
                  headers: {'content-range': '*/211'},
                ),
        ),
      );
      addTearDown(client.dispose);
      final snapshot = await SupabaseAdminRepository(client).fetchSnapshot();
      expect(snapshot[AdminMetric.orders], 211);
      for (final metric in [
        AdminMetric.drivers,
        AdminMetric.customers,
        AdminMetric.kyc,
      ]) {
        expect(snapshot[metric], isNull);
      }
    },
  );
  test(
    'account directory uses admin RPC with literal search and bounded pagination',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            '[]',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseAdminRepository(client);
      await repo.fetchAccounts(
        query: 'an_%@example.invalid',
        role: 'customer',
        offset: 50,
      );
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/rest/v1/rpc/list_admin_accounts');
      expect(jsonDecode(requests.single.body), {
        'p_search': 'an_%@example.invalid',
        'p_role': 'customer',
        'p_offset': 50,
        'p_limit': 51,
      });
      await repo.fetchAccounts(query: '0900000000');
      expect(jsonDecode(requests.last.body)['p_search'], '0900000000');
      await repo.fetchAccounts(query: 'Minh An');
      expect(jsonDecode(requests.last.body)['p_search'], 'Minh An');
    },
  );
  test(
    'order queries filter every status before paging and request no media in the list',
    () async {
      http.Request? request;
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          request = r;
          return http.Response(
            '[]',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await SupabaseAdminOrderRepository(
        client,
      ).fetchPage(query: 'GH-10', status: 'returning', offset: 100);
      expect(request!.url.queryParameters['status'], 'eq.returning');
      expect(request!.url.queryParameters['tracking_code'], 'ilike.%GH-10%');
      expect(request!.url.queryParameters['offset'], '100');
      expect(request!.url.queryParameters['limit'], '51');
      expect(
        request!.url.queryParameters['select'],
        isNot(contains('storage_path')),
      );
    },
  );
}
