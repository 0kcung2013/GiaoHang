import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_config/giaohang_config.dart';

void main() {
  test('extracts session ID from a Supabase access token', () {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'session_id': 'session-123'})))
        .replaceAll('=', '');

    expect(
      sessionIdFromAccessToken('header.$payload.signature'),
      'session-123',
    );
    expect(sessionIdFromAccessToken('invalid-token'), isNull);
  });

  test('revokes other sessions and keeps the new session', () async {
    var revokeCalls = 0;
    var localSignOutCalls = 0;
    final guard = SingleSessionGuard(
      revokeOtherSessions: () async => revokeCalls++,
      signOutCurrentSession: () async => localSignOutCalls++,
    );

    final enforced = await guard.enforce();

    expect(enforced, isTrue);
    expect(revokeCalls, 1);
    expect(localSignOutCalls, 0);
  });

  test(
    'signs out the new session when revoking older sessions fails',
    () async {
      var localSignOutCalls = 0;
      final guard = SingleSessionGuard(
        revokeOtherSessions: () async => throw Exception('network failure'),
        signOutCurrentSession: () async => localSignOutCalls++,
      );

      final enforced = await guard.enforce();

      expect(enforced, isFalse);
      expect(localSignOutCalls, 1);
    },
  );

  test('coalesces concurrent enforcement calls', () async {
    final release = Completer<void>();
    var revokeCalls = 0;
    final guard = SingleSessionGuard(
      revokeOtherSessions: () async {
        revokeCalls++;
        await release.future;
      },
      signOutCurrentSession: () async {},
    );

    final first = guard.enforce();
    final second = guard.enforce();
    release.complete();

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(revokeCalls, 1);
  });
}
