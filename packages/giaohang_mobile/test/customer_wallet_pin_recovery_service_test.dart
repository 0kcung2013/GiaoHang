import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_mobile/core/models/customer_wallet_pin.dart';
import 'package:giaohang_mobile/core/services/customer_wallet_pin_recovery_service.dart';

void main() {
  test(
    'email recovery verifies the code and retries reset with the same proof and request',
    () async {
      final paths = <String>[];
      final resets = <Map<String, dynamic>>[];
      var verificationCount = 0;
      final client = _client((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/recover')) {
          expect(jsonDecode(request.body)['email'], 'customer@example.test');
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/verify')) {
          verificationCount++;
          final body = jsonDecode(request.body);
          expect(body['type'], 'recovery');
          expect(body['token'], '123456');
          return http.Response(jsonEncode(_session('customer-1')), 200);
        }
        if (request.url.path.endsWith('/reset_customer_wallet_pin')) {
          resets.add(
            Map<String, dynamic>.from(jsonDecode(request.body) as Map),
          );
          if (resets.length == 1) throw http.ClientException('Lost response');
          return http.Response(
            '{"ok":true}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/logout')) {
          expect(request.url.queryParameters['scope'], 'local');
        }
        return http.Response('{}', 200);
      });
      final recovery = CustomerWalletPinRecoveryService(
        email: 'customer@example.test',
        customerId: 'customer-1',
        client: client,
      );
      await recovery.sendCode();
      await expectLater(
        recovery.resetPin(code: '123456', newPin: '001234'),
        throwsA(isA<http.ClientException>()),
      );
      await recovery.resetPin(code: '123456', newPin: '001234');
      expect(verificationCount, 1);
      expect(resets[0], resets[1]);
      expect(resets[1]['p_new_pin'], '001234');
      expect(paths.any((path) => path.endsWith('/user')), isFalse);
      await recovery.sendCode();
      expect(paths.where((path) => path.endsWith('/logout')), hasLength(1));
      expect(paths.last, '/auth/v1/recover');
      await recovery.dispose();
    },
  );

  test(
    'a verified code for another user cannot reset the original customer PIN',
    () async {
      var resets = 0;
      final client = _client((request) async {
        if (request.url.path.endsWith('/verify')) {
          return http.Response(jsonEncode(_session('other-customer')), 200);
        }
        if (request.url.path.endsWith('/reset_customer_wallet_pin')) resets++;
        return http.Response('{}', 200);
      });
      final recovery = CustomerWalletPinRecoveryService(
        email: 'customer@example.test',
        customerId: 'customer-1',
        client: client,
      );
      await expectLater(
        recovery.resetPin(code: '123456', newPin: '001234'),
        throwsA(isA<CustomerWalletPinException>()),
      );
      expect(resets, 0);
      await recovery.dispose();
    },
  );
}

SupabaseClient _client(Future<http.Response> Function(http.Request) handle) =>
    SupabaseClient(
      'https://pin-test.example',
      'test-anon-key',
      httpClient: MockClient(handle),
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );

Map<String, dynamic> _session(String userId) => {
  'access_token': 'eyJhbGciOiJIUzI1NiJ9.e30.signature',
  'refresh_token': 'test-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': userId,
    'aud': 'authenticated',
    'email': 'customer@example.test',
    'app_metadata': {},
    'user_metadata': {},
    'created_at': '2026-11-02T00:00:00Z',
  },
};
