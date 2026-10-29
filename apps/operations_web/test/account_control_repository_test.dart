import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:operations_web/features/account_controls/data/account_control_repository.dart';
import 'package:operations_web/features/account_controls/models/account_command.dart';
import 'helpers/account_test_repository.dart';

void main() {
  SupabaseClient clientWith(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.invalid',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(handler),
    );
    addTearDown(client.dispose);
    return client;
  }

  test(
    'directory is bounded, filters server side and parses server account state',
    () async {
      final client = clientWith((r) async {
        expect(r.url.path, '/rest/v1/rpc/list_staff_accounts');
        expect(jsonDecode(r.body), {
          'p_search': 'an_%@example.invalid',
          'p_role': 'driver',
          'p_disabled_only': true,
          'p_offset': 30,
          'p_limit': 30,
        });
        return http.Response(
          jsonEncode({
            'rows': [disabledAccountFixture.toJson()],
            'has_more': true,
            'server_now': '2026-10-21T00:00:00Z',
          }),
          200,
          request: r,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final page = await SupabaseAccountControlRepository(client).list(
        search: ' an_%@example.invalid ',
        role: 'driver',
        disabledOnly: true,
        offset: 30,
      );
      expect(page.rows.single.disabled, isTrue);
      expect(page.rows.single.eventId, disabledAccountFixture.eventId);
      expect(page.hasMore, isTrue);
    },
  );
  test(
    'history uses a stable event cursor and never reads the audit table directly',
    () async {
      final client = clientWith((r) async {
        expect(r.url.path, '/rest/v1/rpc/account_control_history');
        expect(jsonDecode(r.body), {
          'p_user_id': accountFixture.id,
          'p_before_seq': 22,
          'p_limit': 30,
        });
        return http.Response(
          '{"rows":[],"has_more":false,"server_now":"2026-10-21T00:00:00Z"}',
          200,
          request: r,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      expect(
        (await SupabaseAccountControlRepository(
          client,
        ).history(accountFixture.id, before: 22)).rows,
        isEmpty,
      );
    },
  );
  test(
    'receipt validates subject, request and action before confirming a decision',
    () async {
      final command = AccountCommand(
        userId: accountFixture.id,
        action: 'disable',
        reason: 'Đã xác minh vi phạm.',
        durationMinutes: 30,
      );
      var mismatch = true;
      final client = clientWith((r) async {
        expect(jsonDecode(r.body), command.toJson());
        return http.Response(
          jsonEncode({
            'event_id': '00000000-0000-4000-8000-000000000003',
            'user_id': command.userId,
            'request_id': mismatch ? 'wrong-request' : command.requestId,
            'action': 'disable',
            'disabled_until': '2026-10-21T00:30:00Z',
            'already_applied': false,
            'server_now': '2026-10-21T00:00:00Z',
          }),
          200,
          request: r,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repo = SupabaseAccountControlRepository(client);
      await expectLater(repo.apply(command), throwsFormatException);
      mismatch = false;
      await repo.apply(command);
    },
  );
  test('UUIDs are distinct RFC4122 version 4 retry identifiers', () {
    final ids = List.generate(
      100,
      (_) => AccountCommand(
        userId: accountFixture.id,
        action: 'disable',
        reason: 'Vi phạm được xác minh.',
      ).requestId,
    );
    expect(ids.toSet().length, 100);
    for (final id in ids) {
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
  });
}
