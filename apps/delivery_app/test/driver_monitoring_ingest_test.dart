import 'dart:convert';
import 'package:delivery_app/core/location/location_ingest_service.dart';
import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'stationary GPS still reaches monitoring when route distance throttle rejects movement',
    () async {
      final samples = <Map<String, dynamic>>[];
      final client = _client(samples);
      var now = DateTime.utc(2026, 10, 11, 10);
      final ingest = LocationIngestService(
        client: client,
        monitoringClock: () => now,
      );
      addTearDown(() async {
        await ingest.dispose();
        await client.dispose();
      });
      for (var i = 0; i < 2; i++) {
        await ingest.ingest(
          driverProfileId: 'profile',
          driverUserId: 'driver',
          orderId: 'order',
          lat: 10.78,
          lng: 106.7,
          accuracy: 5,
          capturedAt: now,
          prioritySync: true,
          coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
        );
        now = now.add(const Duration(seconds: 15));
      }
      expect(samples, hasLength(2));
      expect(samples.first['p_lat'], samples.last['p_lat']);
      expect(
        samples.first['p_captured_at'],
        isNot(samples.last['p_captured_at']),
      );
    },
  );
  test(
    'monitoring uses measured coordinates independently of map snapping',
    () async {
      final samples = <Map<String, dynamic>>[];
      final client = _client(samples);
      final ingest = LocationIngestService(client: client);
      addTearDown(() async {
        await ingest.dispose();
        await client.dispose();
      });
      await ingest.ingest(
        driverProfileId: 'profile',
        driverUserId: 'driver',
        orderId: 'order',
        lat: 10.78,
        lng: 106.7,
        monitoringPosition: const LatLng(10.779, 106.699),
        accuracy: 8,
        capturedAt: DateTime.now(),
        prioritySync: true,
        coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
      );
      expect(samples.single['p_lat'], 10.779);
      expect(samples.single['p_lng'], 106.699);
      expect(samples.single['p_captured_at'], endsWith('Z'));
    },
  );
  test(
    'restored profile without fresh measurement does not renew monitoring',
    () async {
      final samples = <Map<String, dynamic>>[];
      final client = _client(samples);
      final ingest = LocationIngestService(client: client);
      addTearDown(() async {
        await ingest.dispose();
        await client.dispose();
      });
      await ingest.ingest(
        driverProfileId: 'profile',
        driverUserId: 'driver',
        orderId: 'order',
        lat: 10.78,
        lng: 106.7,
        prioritySync: true,
        coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
      );
      expect(samples, isEmpty);
    },
  );
  test(
    'monitoring failure does not block realtime location pipeline',
    () async {
      final samples = <Map<String, dynamic>>[];
      var edgeCalls = 0;
      final client = _client(
        samples,
        failMonitoring: true,
        onEdge: () => edgeCalls++,
      );
      final ingest = LocationIngestService(client: client);
      addTearDown(() async {
        await ingest.dispose();
        await client.dispose();
      });
      await ingest.ingest(
        driverProfileId: 'profile',
        driverUserId: 'driver',
        orderId: 'order',
        lat: 10.78,
        lng: 106.7,
        accuracy: 5,
        capturedAt: DateTime.now(),
        prioritySync: true,
        coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
      );
      expect(samples, hasLength(1));
      expect(edgeCalls, 1);
    },
  );
}

SupabaseClient _client(
  List<Map<String, dynamic>> samples, {
  bool failMonitoring = false,
  void Function()? onEdge,
}) => SupabaseClient(
  'https://example.supabase.co',
  'test-key',
  httpClient: MockClient((request) async {
    if (request.url.path.endsWith('/record_driver_monitoring_position')) {
      samples.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        failMonitoring
            ? '{"message":"offline","code":"P0001"}'
            : '{"accepted":true}',
        failMonitoring ? 503 : 200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    if (request.url.path.contains('/functions/')) {
      onEdge?.call();
      return http.Response(
        '{"ok":true}',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    if (request.method == 'PATCH' && request.url.path.endsWith('/drivers')) {
      return http.Response('', 204, request: request);
    }
    throw StateError('Unexpected ${request.url.path}');
  }),
);
