import 'dart:convert';

import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/providers/driver_wallet_providers.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:delivery_app/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:delivery_app/features/driver/screens/free_pick/driver_free_pick_screen.dart';
import 'package:delivery_app/features/driver/screens/free_pick/widgets/free_pick_map_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _devicePosition = LatLng(11.0308, 106.6220);
const _demoPosition = LatLng(10.7790, 106.6765);
final _tilePng = image.encodePng(image.Image(width: 1, height: 1));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': 'test-access-token',
            'refresh_token': 'test-refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'driver-user',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'taixe@gmail.com',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
              'created_at': '2026-10-08T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'taixe@gmail.com',
      password: 'test-password',
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  _testWithMapTiles('FreePick uses demo GPS for its marker and camera', (
    tester,
  ) async {
    await _pumpScreen(tester, DriverLocationMode.demoHcm);

    _expectMapPosition(tester, _demoPosition);
  });

  _testWithMapTiles('locating again keeps the configured demo position', (
    tester,
  ) async {
    await _pumpScreen(tester, DriverLocationMode.demoHcm);
    final canvas = tester.widget<FreePickMapCanvas>(
      find.byType(FreePickMapCanvas),
    );
    canvas.mapController!.move(_devicePosition, 13);

    await tester.tap(find.byTooltip('Về vị trí hiện tại'));
    await tester.pumpAndSettle();

    _expectMapPosition(tester, _demoPosition);
  });

  _testWithMapTiles(
    'changing GPS mode recenters FreePick without reopening it',
    (tester) async {
      final container = await _pumpScreen(tester, DriverLocationMode.deviceGps);
      _expectMapPosition(tester, _devicePosition);

      container.read(driverLocationModeProvider.notifier).state =
          DriverLocationMode.demoHcm;
      await tester.pumpAndSettle();
      _expectMapPosition(tester, _demoPosition);

      container.read(driverLocationModeProvider.notifier).state =
          DriverLocationMode.demoCurrentPosition;
      await tester.pumpAndSettle();
      _expectMapPosition(tester, _devicePosition);
    },
  );

  _testWithMapTiles(
    'uses the stored map position when device GPS is unavailable',
    (tester) async {
      await _pumpScreen(
        tester,
        DriverLocationMode.demoHcm,
        hasDeviceGps: false,
      );

      _expectMapPosition(tester, _demoPosition);
    },
  );
}

void _testWithMapTiles(String description, WidgetTesterCallback body) {
  // Include refreshes and mode changes so every rebuilt tile layer is mocked.
  testWidgets(
    description,
    (tester) => http.runWithClient(
      () => body(tester),
      () => MockClient(
        (request) async => http.Response.bytes(
          _tilePng,
          200,
          headers: {'content-type': 'image/png'},
        ),
      ),
    ),
  );
}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester,
  DriverLocationMode mode, {
  bool hasDeviceGps = true,
}) async {
  final driver = DriverModel(
    id: 'driver-profile',
    userId: 'driver-user',
    isAvailable: false,
    updatedAt: DateTime(2026, 10, 8),
    totalDeliveries: 0,
    currentLat: _demoPosition.latitude,
    currentLng: _demoPosition.longitude,
  );
  final container = ProviderContainer(
    overrides: [
      driverByUserIdProvider('driver-user').overrideWith((ref) async => driver),
      driverOrdersProvider(
        'driver-user',
      ).overrideWith((ref) => Stream.value([])),
      availableOrdersProvider(
        'driver-user',
      ).overrideWith((ref) => Stream.value([])),
      driverAcceptanceStateProvider('driver-user').overrideWith(
        (ref) => Stream.value(
          DriverAcceptanceState(serverNow: DateTime(2026, 10, 8)),
        ),
      ),
      driverWalletChangesProvider.overrideWith((ref) => const Stream.empty()),
      currentPositionProvider.overrideWith(
        (ref) async => hasDeviceGps
            ? Position(
                latitude: _devicePosition.latitude,
                longitude: _devicePosition.longitude,
                timestamp: DateTime(2026, 10, 8),
                accuracy: 1,
                altitude: 0,
                altitudeAccuracy: 0,
                heading: 0,
                headingAccuracy: 0,
                speed: 0,
                speedAccuracy: 0,
              )
            : null,
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  tester.view.devicePixelRatio = 1;
  // The default test font has wider attribution glyphs than the app font.
  tester.view.physicalSize = const Size(600, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  container.read(driverLocationModeProvider.notifier).state = mode;
  await container.read(driverByUserIdProvider('driver-user').future);
  await container.read(currentPositionProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: DriverFreePickScreen())),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void _expectMapPosition(WidgetTester tester, LatLng expected) {
  final canvas = tester.widget<FreePickMapCanvas>(
    find.byType(FreePickMapCanvas),
  );
  expect(canvas.driverPosition, expected);
  expect(find.byType(CircleLayer), findsNothing);
  final center = canvas.mapController!.camera.center;
  // Camera fitting includes asymmetric padding for the screen controls.
  expect(center.latitude, closeTo(expected.latitude, 0.002));
  expect(center.longitude, closeTo(expected.longitude, 0.002));
}
