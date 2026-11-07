import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_mobile/core/location/location_ingest_service.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';

void main() {
  test(
    'invalid physical fixes never enter latest/history; new parcel uses actual coordinates',
    () async {
      final now = DateTime.now().toUtc();
      final sent = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((req) async {
          sent.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(
            '{"ok":true,"pg_updated":true}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final ingest = LocationIngestService(client: client, clock: () => now);
      try {
        for (final fix in [
          (now.subtract(const Duration(minutes: 2)), 8.0),
          (now, 80.0),
          (now.add(const Duration(minutes: 1)), 8.0),
        ]) {
          await ingest.ingest(
            driverProfileId: 'profile',
            driverUserId: 'driver',
            orderId: 'new',
            lat: 10.81,
            lng: 106.73,
            capturedAt: fix.$1,
            accuracy: fix.$2,
            force: true,
            coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
          );
        }
        expect(sent, isEmpty);
        await ingest.ingest(
          driverProfileId: 'profile',
          driverUserId: 'driver',
          orderId: 'new',
          lat: 10.81,
          lng: 106.73,
          force: true,
          coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
        );
        expect(sent.single['lat'], 10.81);
        expect(sent.single['lng'], 106.73);
        expect(sent.single['order_id'], 'new');
      } finally {
        await ingest.dispose();
        await client.dispose();
      }
    },
  );
}
