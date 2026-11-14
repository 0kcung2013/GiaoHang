import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_mobile/features/auth/password_recovery/data/password_recovery_service.dart';

void main() {
  test(
    'recovery updates only after proof and signs out only its own session',
    () async {
      final paths = <String>[];
      final client = _client((request) async {
        paths.add(request.url.path);
        final body = request.body.isEmpty ? null : jsonDecode(request.body);
        if (request.url.path.endsWith('/recover')) {
          expect(body['email'], 'customer@example.test');
        }
        if (request.url.path.endsWith('/verify')) {
          expect(body['type'], 'recovery');
          expect(body['token'], '001234');
          return http.Response(jsonEncode(_session()), 200);
        }
        if (request.method == 'PUT') {
          expect(
            request.headers['Authorization'],
            'Bearer ${_session()['access_token']}',
          );
          expect(body, {'password': 'NewPassword9!'});
          return http.Response(jsonEncode({'user': _session()['user']}), 200);
        }
        if (request.url.path.endsWith('/logout')) {
          expect(request.url.queryParameters['scope'], 'local');
        }
        return http.Response('{}', 200);
      });
      final unrelated = _client(
        (_) async => http.Response(jsonEncode(_session()), 200),
      );
      await unrelated.auth.verifyOTP(
        email: 'customer@example.test',
        token: '001234',
        type: OtpType.recovery,
      );
      final mainSession = unrelated.auth.currentSession;
      final service = PasswordRecoveryService(client: client);
      await expectLater(
        service.updatePassword('NewPassword9!'),
        throwsA(isA<AuthException>()),
      );
      expect(paths, isEmpty);
      await service.sendCode(' customer@example.test ');
      await service.verifyCode('customer@example.test', '001234');
      await service.updatePassword('NewPassword9!');
      expect(paths, [
        '/auth/v1/recover',
        '/auth/v1/verify',
        '/auth/v1/user',
        '/auth/v1/logout',
      ]);
      expect(client.auth.currentSession, isNull);
      expect(unrelated.auth.currentSession, same(mainSession));
      await service.dispose();
      await unrelated.dispose();
    },
  );

  test(
    'wrong email proof is cleaned up and cannot change a password',
    () async {
      var writes = 0;
      final client = _client((request) async {
        if (request.method == 'PUT') writes++;
        if (request.url.path.endsWith('/verify')) {
          final session = _session();
          (session['user'] as Map)['email'] = 'other@example.test';
          return http.Response(jsonEncode(session), 200);
        }
        return http.Response('{}', 200);
      });
      final service = PasswordRecoveryService(client: client);
      await expectLater(
        service.verifyCode('customer@example.test', '001234'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        service.updatePassword('NewPassword9!'),
        throwsA(isA<AuthException>()),
      );
      expect(writes, 0);
      expect(client.auth.currentSession, isNull);
      await service.dispose();
    },
  );

  test(
    'retrying a rejected password retains the verified recovery session',
    () async {
      var writes = 0;
      final service = PasswordRecoveryService(
        client: _client((request) async {
          if (request.url.path.endsWith('/verify')) {
            return http.Response(jsonEncode(_session()), 200);
          }
          if (request.method == 'PUT') {
            writes++;
            if (writes == 1) {
              return http.Response(
                '{"code":"same_password","msg":"Same password"}',
                422,
              );
            }
            return http.Response(jsonEncode({'user': _session()['user']}), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await service.verifyCode('customer@example.test', '001234');
      await expectLater(
        service.updatePassword('OldPassword9!'),
        throwsA(isA<AuthException>()),
      );
      await service.updatePassword('NewPassword9!');
      expect(writes, 2);
      await service.dispose();
    },
  );

  test(
    'sending another code invalidates the previous verified session',
    () async {
      final service = PasswordRecoveryService(
        client: _client(
          (request) async => http.Response(
            request.url.path.endsWith('/verify')
                ? jsonEncode(_session())
                : '{}',
            200,
          ),
        ),
      );
      await service.verifyCode('customer@example.test', '001234');
      await service.sendCode('other@example.test');
      await expectLater(
        service.updatePassword('NewPassword9!'),
        throwsA(isA<AuthException>()),
      );
      await service.dispose();
    },
  );

  test(
    'closing during verification waits and revokes the late recovery session',
    () async {
      final response = Completer<http.Response>();
      var logouts = 0;
      final service = PasswordRecoveryService(
        client: _client((request) async {
          if (request.url.path.endsWith('/verify')) return response.future;
          if (request.url.path.endsWith('/logout')) logouts++;
          return http.Response('{}', 200);
        }),
      );
      final verification = service.verifyCode(
        'customer@example.test',
        '001234',
      );
      final cleanup = service.dispose();
      response.complete(http.Response(jsonEncode(_session()), 200));
      await verification;
      await cleanup;
      expect(logouts, 1);
      await expectLater(
        service.sendCode('customer@example.test'),
        throwsStateError,
      );
    },
  );
}

SupabaseClient _client(Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient(
      'https://recovery.example.test',
      'test-anon-key',
      httpClient: MockClient(handler),
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );

Map<String, dynamic> _session() => {
  'access_token': 'eyJhbGciOiJIUzI1NiJ9.e30.signature',
  'refresh_token': 'recovery-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': 'customer-1',
    'aud': 'authenticated',
    'email': 'customer@example.test',
    'app_metadata': {},
    'user_metadata': {},
    'created_at': '2026-11-07T00:00:00Z',
  },
};
