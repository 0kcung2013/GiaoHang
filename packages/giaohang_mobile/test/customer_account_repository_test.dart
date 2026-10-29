import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/customer/screens/account/data/customer_account_repository.dart';
import 'package:giaohang_mobile/features/customer/screens/account/data/customer_support_inbox_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/customer_account_fixtures.dart';
import 'review_service_test.dart' show reviewTestClient, response;

void main() {
  test(
    'profile writes are limited to the signed-in customer and self-service columns',
    () async {
      final client = await reviewTestClient((request) {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/rest/v1/users');
        expect(request.url.queryParameters['id'], 'eq.actor-1');
        expect(request.url.queryParameters['role'], 'eq.customer');
        expect(jsonDecode(request.body), {
          'full_name': 'Tên mới',
          'phone': '0901234567',
        });
        return response(request, {
          ...customerAccountFixture.toJson(),
          'full_name': 'Tên mới',
        });
      });
      addTearDown(client.dispose);
      final profile = await SupabaseCustomerAccountRepository(client).save(
        userId: 'actor-1',
        fullName: ' Tên mới ',
        phone: '+84 901 234 567',
      );
      expect(profile.fullName, 'Tên mới');
    },
  );

  test(
    'a stale profile from another session cannot update the new owner',
    () async {
      var writes = 0;
      final client = await reviewTestClient((request) {
        writes++;
        return response(request, {});
      });
      addTearDown(client.dispose);
      await expectLater(
        SupabaseCustomerAccountRepository(client).save(
          userId: 'another-user',
          fullName: 'Tên khách',
          phone: '0901234567',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(writes, 0);
    },
  );

  test('invalid contact data is rejected before sending a request', () async {
    var writes = 0;
    final client = await reviewTestClient((request) {
      writes++;
      return response(request, {});
    });
    addTearDown(client.dispose);
    for (final value in [
      ('A', '0901234567'),
      ('Khách hàng', '123'),
      ('Khách hàng', '090123456789999'),
      ('Khách hàng', '0901234567abc'),
    ]) {
      await expectLater(
        SupabaseCustomerAccountRepository(
          client,
        ).save(userId: 'actor-1', fullName: value.$1, phone: value.$2),
        throwsFormatException,
      );
    }
    expect(writes, 0);
  });

  test('permission errors are never treated as a successful save', () async {
    final client = await reviewTestClient(
      (r) => response(r, {'code': '42501', 'message': 'denied'}, 403),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseCustomerAccountRepository(
        client,
      ).save(userId: 'actor-1', fullName: 'Khách hàng', phone: '0901234567'),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'support inbox is requester-scoped and paginated on the server',
    () async {
      var calls = 0;
      final client = await reviewTestClient((request) {
        calls++;
        expect(request.url.path, '/rest/v1/support_tickets');
        expect(request.url.queryParameters['requester_id'], 'eq.actor-1');
        expect(
          request.url.queryParameters['status']?.replaceAll('"', ''),
          'in.(resolved,closed)',
        );
        expect(request.url.queryParameters['offset'], '30');
        expect(request.url.queryParameters['limit'], '30');
        return response(request, []);
      });
      addTearDown(client.dispose);
      expect(
        await SupabaseCustomerSupportInboxRepository(
          client,
        ).fetch(closed: true, offset: 30),
        isEmpty,
      );
      expect(calls, 1);
    },
  );
}
