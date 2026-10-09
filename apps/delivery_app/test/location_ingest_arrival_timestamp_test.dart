import 'dart:convert';

import 'package:delivery_app/core/location/location_ingest_service.dart';
import 'package:delivery_app/features/driver/screens/navigation/data/driver_delivery_arrival_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final edgeAvailable in [true, false]) {
    test(
      'forced arrival sync sends UTC when edgeAvailable=$edgeAvailable',
      () async {
        final writes = <Map<String, dynamic>>[];
        var confirmations = 0;
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith(
              '/rpc/confirm_driver_delivery_arrival',
            )) {
              confirmations++;
              final timestamp = writes.last['location_updated_at'] as String;
              // Postgres runs in UTC and interprets timestamps without a zone as UTC.
              final stored = DateTime.parse(
                timestamp.endsWith('Z') ? timestamp : '${timestamp}Z',
              );
              final serverNow = DateTime.now().toUtc();
              final age = serverNow.difference(stored);
              if (age < const Duration(seconds: -5) ||
                  age > const Duration(seconds: 60)) {
                return http.Response(
                  '{"message":"DELIVERY_LOCATION_STALE","code":"23514"}',
                  400,
                  headers: {'content-type': 'application/json'},
                  request: request,
                );
              }
              return http.Response(
                jsonEncode({
                  'delivery_arrived_at': serverNow.toIso8601String(),
                  'server_now': serverNow.toIso8601String(),
                  'can_report_recipient': false,
                }),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            if (request.url.path.contains('/functions/')) {
              return http.Response(
                edgeAvailable ? '{"ok":true}' : '{"error":"unavailable"}',
                edgeAvailable ? 200 : 503,
                headers: {'content-type': 'application/json'},
              );
            }
            expect(request.method, 'PATCH');
            expect(request.url.path, '/rest/v1/drivers');
            writes.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              '',
              204,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        final ingest = LocationIngestService(client: client);
        final arrival = DriverDeliveryArrivalRepository(client: client);
        final started = DateTime.now().toUtc();
        try {
          // Two stationary samples: force must refresh the timestamp on retry.
          for (var i = 0; i < 2; i++) {
            await ingest.ingest(
              driverProfileId: 'profile',
              driverUserId: 'driver',
              lat: 10,
              lng: 106,
              force: true,
              prioritySync: true,
            );
            final confirmed = await arrival.confirm('order');
            expect(confirmed.arrivedAt, isNotNull);
            expect(confirmed.canReport, isFalse);
          }
          expect(confirmations, 2);
          expect(writes, hasLength(2));
          for (final write in writes) {
            final timestamp = write['location_updated_at'] as String;
            expect(
              timestamp,
              endsWith('Z'),
              reason: 'Postgres must receive an explicit timezone',
            );
            final parsed = DateTime.parse(timestamp);
            expect(parsed.isUtc, isTrue);
            expect(parsed.isBefore(started), isFalse);
            expect(
              DateTime.now().toUtc().difference(parsed).inSeconds,
              lessThan(5),
            );
            expect(write['updated_at'], timestamp);
          }
        } finally {
          await ingest.dispose();
          await client.dispose();
        }
      },
    );
  }
}
