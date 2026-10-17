import 'dart:convert';

import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/location/location_ingest_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'one-second active GPS samples only send the newest sample every 5s',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      for (var second = 0; second <= 12; second++) {
        await harness.sample(second);
      }
      expect(harness.edgeSeconds, [0, 5, 10]);
      expect(harness.edgeBodies[1]['lat'], 10 + 5 * 0.000001);
      expect(harness.edgeBodies[2]['lat'], 10 + 10 * 0.000001);
      expect(
        harness.patches,
        isEmpty,
        reason: 'Edge success must not trigger a client PATCH',
      );
      expect(
        harness.edgeBodies.every((body) => !body.containsKey('force_pg_sync')),
        isTrue,
      );
    },
  );

  test(
    'fallback PG writes use 10s despite receiving active samples each second',
    () async {
      final harness = _Harness(edgeAvailable: false);
      addTearDown(harness.dispose);
      for (var second = 0; second <= 20; second++) {
        await harness.sample(second);
      }
      expect(harness.patchSeconds, [0, 10, 20]);
      expect(harness.patches.last['current_lat'], 10 + 20 * 0.000001);
      expect(
        harness.patches.every(
          (body) => (body['location_updated_at'] as String).endsWith('Z'),
        ),
        isTrue,
      );
    },
  );

  test(
    'critical sync reaches Edge immediately and restarts the 5s sample window',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await harness.sample(0);
      await harness.sample(3, force: true);
      await harness.sample(4);
      await harness.sample(8);
      expect(harness.edgeSeconds, [0, 3, 8]);
      expect(harness.edgeBodies[1]['force_pg_sync'], isTrue);
      expect(
        harness.patches,
        isEmpty,
        reason: 'The forced Edge write also replaces the local PATCH',
      );
    },
  );

  test(
    'critical fallback bypasses 10s and resets the fallback write window',
    () async {
      final harness = _Harness(edgeAvailable: false);
      addTearDown(harness.dispose);
      for (final second in [0, 3, 4, 8, 13]) {
        await harness.sample(second, force: second == 3);
      }
      expect(harness.patchSeconds, [0, 3, 13]);
    },
  );

  test(
    'Edge-to-fallback transition respects the last confirmed PG write',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await harness.sample(0);
      harness.edgeAvailable = false;
      await harness.sample(5);
      expect(harness.patches, isEmpty);
      await harness.sample(10);
      expect(harness.patchSeconds, [10]);
    },
  );

  test(
    'stationary monitoring remains on its own 5s cadence before ingest filtering',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      for (var second = 0; second <= 12; second++) {
        await harness.sample(second, monitor: true);
      }
      expect(harness.monitoringSeconds, [0, 5, 10]);
      expect(harness.edgeSeconds, [0, 5, 10]);
      expect(harness.patches, isEmpty);
      expect(harness.monitoringSamples.last['p_captured_at'], endsWith('Z'));
    },
  );

  test(
    'legacy Edge without forced-write confirmation still performs critical local sync',
    () async {
      final harness = _Harness(pgUpdated: false);
      addTearDown(harness.dispose);
      await harness.sample(0, force: true);
      expect(harness.edgeBodies.single['force_pg_sync'], isTrue);
      expect(harness.patchSeconds, [0]);
    },
  );
}

class _Harness {
  _Harness({this.edgeAvailable = true, this.pgUpdated = true}) {
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/record_driver_monitoring_position')) {
          monitoringSeconds.add(second);
          monitoringSamples.add(body);
          return _response('{"accepted":true}', request: request);
        }
        if (request.url.path.endsWith('/ingest-driver-location')) {
          edgeSeconds.add(second);
          edgeBodies.add(body);
          return _response(
            edgeAvailable
                ? jsonEncode({'ok': true, 'pg_updated': pgUpdated})
                : '{"error":"unavailable"}',
            status: edgeAvailable ? 200 : 503,
            request: request,
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path.endsWith('/drivers')) {
          patchSeconds.add(second);
          patches.add(body);
          return _response('', status: 204, request: request);
        }
        throw StateError('Unexpected ${request.method} ${request.url.path}');
      }),
    );
    ingest = LocationIngestService(
      client: client,
      clock: () => now,
      monitoringClock: () => now,
    );
  }

  static final start = DateTime.utc(2026, 10, 12, 8);
  DateTime now = start;
  bool edgeAvailable;
  bool pgUpdated;
  late final SupabaseClient client;
  late final LocationIngestService ingest;
  final edgeSeconds = <int>[];
  final edgeBodies = <Map<String, dynamic>>[];
  final patchSeconds = <int>[];
  final patches = <Map<String, dynamic>>[];
  final monitoringSeconds = <int>[];
  final monitoringSamples = <Map<String, dynamic>>[];
  int get second => now.difference(start).inSeconds;

  Future<void> sample(
    int second, {
    bool force = false,
    bool monitor = false,
  }) async {
    now = start.add(Duration(seconds: second));
    await ingest.ingest(
      driverProfileId: 'profile',
      driverUserId: 'driver',
      orderId: monitor ? 'order' : null,
      lat: monitor ? 10 : 10 + second * 0.000001,
      lng: 106,
      accuracy: monitor ? 5 : null,
      capturedAt: monitor ? now : null,
      force: force,
      prioritySync: true,
      coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
    );
  }

  static http.Response _response(
    String body, {
    int status = 200,
    required http.Request request,
  }) => http.Response(
    body,
    status,
    headers: {'content-type': 'application/json'},
    request: request,
  );

  Future<void> dispose() async {
    await ingest.dispose();
    await client.dispose();
  }
}
