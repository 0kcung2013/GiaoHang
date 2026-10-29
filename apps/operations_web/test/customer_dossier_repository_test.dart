import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/account_controls/data/customer_dossier_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final orders in [true, false]) {
    test(
      'dossier ${orders ? 'orders' : 'tickets'} is owner-filtered and limited on the server',
      () async {
        final client = SupabaseClient(
          'https://supabase.example.invalid',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            expect(
              request.url.path,
              orders ? '/rest/v1/orders' : '/rest/v1/support_tickets',
            );
            expect(
              request.url.queryParameters[orders
                  ? 'customer_id'
                  : 'requester_id'],
              'eq.customer-1',
            );
            expect(request.url.queryParameters['offset'], '30');
            expect(request.url.queryParameters['limit'], '31');
            return http.Response(
              jsonEncode([]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabaseCustomerDossierRepository(client);
        if (orders) {
          expect(await repository.orders('customer-1', offset: 30), isEmpty);
        } else {
          expect(await repository.tickets('customer-1', offset: 30), isEmpty);
        }
      },
    );
  }
}
