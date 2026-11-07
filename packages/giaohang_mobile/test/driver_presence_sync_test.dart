import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/location/location_ingest_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'silent RLS rejection of latest update is not reported as synced',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient(
          (request) async => http.Response(
            request.url.path.contains('/functions/')
                ? '{"ok":true,"pg_updated":false}'
                : '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final service = LocationIngestService(client: client);
      addTearDown(() async {
        await service.dispose();
        await client.dispose();
      });
      expect(
        await service.ingestOnlinePresence(
          driverProfileId: 'profile',
          driverUserId: 'driver',
          lat: 10.8,
          lng: 106.7,
          accuracy: 126,
          capturedAt: DateTime.now(),
        ),
        isFalse,
      );
    },
  );

  test(
    'online heartbeat requires confirmed latest write, not just Edge 200',
    () async {
      final paths = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.contains('/functions/')) {
            return http.Response(
              '{"ok":true,"pg_updated":false}',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.contains('/rpc/')) {
            return http.Response(
              '{"id":"profile","user_id":"driver"}',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '[{"id":"profile"}]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final service = LocationIngestService(client: client);
      addTearDown(() async {
        await service.dispose();
        await client.dispose();
      });
      final synced = await service.ingestOnlinePresence(
        driverProfileId: 'profile',
        lat: 10.8,
        lng: 106.7,
        accuracy: 126,
        capturedAt: DateTime.now(),
      );
      expect(synced, isTrue);
      expect(
        paths,
        contains('/rest/v1/drivers'),
        reason:
            'An unconfirmed Edge write must use the existing latest fallback',
      );
    },
  );

  test(
    'online retries Edge after an outage and never enqueues order history',
    () async {
      var now = DateTime.utc(2026, 11, 3);
      var edgeCalls = 0;
      final bodies = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/functions/')) {
            edgeCalls++;
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              edgeCalls == 1
                  ? '{"error":"outage"}'
                  : '{"ok":true,"pg_updated":true}',
              edgeCalls == 1 ? 503 : 200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.contains('/rpc/')) {
            return http.Response(
              '{"id":"profile","user_id":"driver"}',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '[{"id":"profile"}]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final service = LocationIngestService(client: client, clock: () => now);
      addTearDown(() async {
        await service.dispose();
        await client.dispose();
      });
      for (var i = 0; i < 2; i++) {
        await service.ingestOnlinePresence(
          driverProfileId: 'profile',
          lat: 10.8,
          lng: 106.7,
          accuracy: 126,
          capturedAt: now,
        );
        now = now.add(const Duration(seconds: 30));
      }
      expect(
        edgeCalls,
        2,
        reason: 'An outage must not disable Edge for the whole session',
      );
      expect(bodies.every((b) => !b.containsKey('order_id')), isTrue);
    },
  );
}
