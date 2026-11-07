import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/location/driver_presence_session.dart';
import 'package:giaohang_mobile/core/location/location_ingest_service.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/driver_online_presence_provider.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/core/services/driver_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver_presence_session_test.dart' show Gps, fix;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in DriverLocationMode.values) {
    for (final email in [
      'taixe@gmail.com',
      'taixe2@gmail.com',
      'taixe3@gmail.com',
    ]) {
      test(
        '$mode $email: PIN origin, heartbeat and shared marker use the same resolved point exactly once',
        () async {
          final writes = <LatLng>[];
          final client = SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              if (request.url.path.startsWith('/auth/')) {
                return http.Response(
                  jsonEncode({
                    'access_token': 'fixture-token',
                    'refresh_token': 'fixture-refresh',
                    'token_type': 'bearer',
                    'expires_in': 3600,
                    'user': {
                      'id': 'driver',
                      'email': email,
                      'aud': 'authenticated',
                      'created_at': '2026-11-03T00:00:00Z',
                      'app_metadata': {},
                      'user_metadata': {},
                    },
                  }),
                  200,
                  request: request,
                  headers: {'content-type': 'application/json'},
                );
              }
              expect(request.url.path, '/functions/v1/ingest-driver-location');
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body.containsKey('order_id'), isFalse);
              writes.add(
                LatLng(
                  (body['lat'] as num).toDouble(),
                  (body['lng'] as num).toDouble(),
                ),
              );
              return http.Response(
                '{"ok":true,"pg_updated":true}',
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }),
          );
          await client.auth.signInWithPassword(
            email: email,
            password: 'fixture-only',
          );
          final ingest = LocationIngestService(client: client);
          final raw = fix(DateTime.now(), accuracy: 8);
          final expected = mode.resolveRawGps(
            email: email,
            lat: raw.latitude,
            lng: raw.longitude,
          );
          Map<String, dynamic>? onlineParams;
          final driver = DriverService(
            client: client,
            locationIngest: ingest,
            presenceInvoker: (_) async {},
            rpcInvoker: (_, params) async {
              onlineParams = params;
              return {'status': 'online', 'offered_order_id': null};
            },
          );
          await driver.setOnlineWithLocation(
            driverProfileId: 'profile',
            lat: raw.latitude,
            lng: raw.longitude,
            pin: '123456',
            coordinateSpace: mode.rawGpsCoordinateSpace,
          );
          expect(
            LatLng(
              onlineParams!['p_lat'] as double,
              onlineParams!['p_lng'] as double,
            ),
            expected,
          );
          final c = ProviderContainer(
            overrides: [
              driverLocationModeProvider.overrideWith((_) => mode),
              locationIngestServiceProvider.overrideWithValue(ingest),
              driverOnlineLocationServiceProvider.overrideWithValue(
                Gps(() async => raw),
              ),
            ],
          );
          final synced = Completer<void>();
          final physical = c.listen(driverPhysicalPositionProvider, (_, _) {});
          final arrival = c.listen(driverArrivalFixProvider, (_, _) {});
          final presence = c.listen(driverOnlinePresenceProvider('profile'), (
            _,
            next,
          ) {
            if (next.valueOrNull == DriverPresenceStatus.ready &&
                !synced.isCompleted) {
              synced.complete();
            }
          });
          try {
            await synced.future.timeout(const Duration(seconds: 3));
            expect(writes, hasLength(2));
            expect(writes.every((point) => point == expected), isTrue);
            expect(physical.read(), expected);
            expect(arrival.read()!.position, expected);
            expect(
              ingest.resolveCoordinates(
                coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
                lat: expected.latitude,
                lng: expected.longitude,
              ),
              expected,
              reason:
                  'Coordinates already resolved for simulation must not receive a second offset',
            );
          } finally {
            presence.close();
            physical.close();
            arrival.close();
            c.dispose();
            await ingest.dispose();
            await client.dispose();
          }
        },
      );
    }
  }
}
