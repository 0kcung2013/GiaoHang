import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/services/business_settings_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/order_submission_payload.dart';

void main() {
  test(
    'pre-login contact uses the public endpoint and reflects the configured company',
    () async {
      final client = SupabaseClient(
        'https://settings.invalid',
        'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/functions/v1/business-contact');
          return http.Response(
            jsonEncode({
              'company_name': 'Đơn vị thử nghiệm',
              'support_email': 'help@example.com',
              'support_phone': '0901234567',
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final contact = await BusinessSettingsService(client: client).contact();
      expect(contact.companyName, 'Đơn vị thử nghiệm');
      expect(contact.supportEmail, 'help@example.com');
      expect(contact.supportPhone, '0901234567');
    },
  );
  test(
    'creation payload carries quoted revision/distance but cannot write policy snapshots',
    () {
      final order = OrderModel.fromJson({
        'id': 'draft',
        'customer_id': 'customer',
        'status': 'pending',
        'delivery_fee': 35000,
        'created_at': '2026-10-26T00:00:00Z',
        'updated_at': '2026-10-26T00:00:00Z',
        'business_policy': BusinessSettings(revision: 5).toJson(),
      }).copyWith(settingsRevision: 5, quotedDistanceMeters: 3000);
      final payload = buildOrderSubmissionPayload(
        order.copyWith(serviceType: 'standard'),
      );
      expect(payload['settings_revision'], 5);
      expect(payload['quoted_distance_m'], 3000);
      expect(payload.containsKey('business_policy'), isFalse);
      expect(order.toJson().containsKey('settings_revision'), isFalse);
    },
  );
  test(
    'legacy snapshots retain their configured distance bands and rounding',
    () {
      final settings = BusinessSettings(
        revision: 2,
        values: {
          'base_fee': 25000,
          'included_distance_m': 1000,
          'long_distance_threshold_m': 5000,
          'standard_per_km': 6000,
          'long_distance_per_km': 3000,
          'rounding_unit': 500,
          'return_fee_rate_bps': 7500,
        },
      );
      final fee = DeliveryPricingPolicy.calculate(
        distanceMeters: 6100,
        settings: settings,
      );
      expect(fee.total, 52500);
      expect(fee.standardPerKm, 6000);
      expect(fee.longDistancePerKm, 3000);
      expect(settings.returnFee(40000), 30000);
      expect(
        BusinessSettings.fromJson(settings.toJson()).values,
        settings.values,
      );
    },
  );

  test(
    'fetches current operational values and never substitutes stale defaults on error',
    () async {
      var fail = false;
      final client = SupabaseClient(
        'https://settings.invalid',
        'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/get_business_settings');
          return http.Response(
            jsonEncode(
              fail
                  ? {'message': 'offline', 'code': 'ERROR'}
                  : BusinessSettings(
                      revision: 4,
                      values: {'max_cod': 3000000},
                    ).toJson(),
            ),
            fail ? 503 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final service = BusinessSettingsService(client: client);
      expect((await service.load()).maxCod, 3000000);
      fail = true;
      await expectLater(service.load(), throwsA(isA<PostgrestException>()));
    },
  );
}
