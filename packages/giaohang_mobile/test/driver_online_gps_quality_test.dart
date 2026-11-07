import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_mobile/core/location/location_ingest_service.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/core/providers/driver_online_presence_provider.dart';
import 'package:giaohang_mobile/core/services/location_service.dart';
import 'package:giaohang_mobile/core/location/physical_gps_policy.dart';

class _BrowserLocation extends LocationService {
  _BrowserLocation(this.fix);
  final Position fix;
  @override
  Future<Position?> getCurrentPosition() async => fix;
  @override
  void startTracking({
    required void Function(Position) onPosition,
    void Function(String)? onError,
    int distanceFilterMeters = 10,
  }) {}
  @override
  void stopTracking() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'discovery tolerance does not relax delivery evidence or timestamp checks',
    () {
      final now = DateTime.now();
      expect(
        PhysicalGpsPolicy.accepts(
          now: now,
          capturedAt: now,
          accuracy: 126,
          onlinePresence: true,
        ),
        isTrue,
      );
      expect(
        PhysicalGpsPolicy.accepts(now: now, capturedAt: now, accuracy: 126),
        isFalse,
      );
      expect(
        PhysicalGpsPolicy.accepts(
          now: now,
          capturedAt: now,
          accuracy: 201,
          onlinePresence: true,
        ),
        isFalse,
      );
      expect(
        PhysicalGpsPolicy.accepts(
          now: now,
          capturedAt: now.subtract(const Duration(seconds: 91)),
          accuracy: 126,
          onlinePresence: true,
        ),
        isFalse,
      );
      expect(
        PhysicalGpsPolicy.accepts(
          now: now,
          capturedAt: now.add(const Duration(seconds: 16)),
          accuracy: 126,
          onlinePresence: true,
        ),
        isFalse,
      );
    },
  );
  test(
    'idle browser driver with fresh 126m GPS stays discoverable for invitations',
    () async {
      final writes = <Map<String, dynamic>>[];
      final published = Completer<void>();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/functions/v1/ingest-driver-location');
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (!published.isCompleted) published.complete();
          return http.Response(
            '{"ok":true,"pg_updated":true}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final ingest = LocationIngestService(client: client);
      final fix = Position(
        latitude: 11.03073,
        longitude: 106.622,
        accuracy: 126,
        timestamp: DateTime.now(),
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      final container = ProviderContainer(
        overrides: [
          driverOnlineLocationServiceProvider.overrideWithValue(
            _BrowserLocation(fix),
          ),
          locationIngestServiceProvider.overrideWithValue(ingest),
        ],
      );
      final subscription = container.listen(
        driverLocationStreamProvider('profile'),
        (_, _) {},
      );
      try {
        // Reproduces the online dashboard's GPS path, including its quality gate.
        await published.future.timeout(const Duration(seconds: 3));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          writes,
          hasLength(1),
          reason:
              'Online presence must not silently stop at browser accuracy 126m',
        );
        expect(writes.single['lat'], fix.latitude);
        expect(writes.single['lng'], fix.longitude);
        expect(writes.single.containsKey('order_id'), isFalse);
      } finally {
        subscription.close();
        container.dispose();
        await ingest.dispose();
        await client.dispose();
      }
    },
  );
}
