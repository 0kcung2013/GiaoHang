import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/core/location/tracking_location_freshness.dart';
import 'package:giaohang_mobile/core/widgets/delivery_map_markers.dart';
import 'package:giaohang_mobile/core/services/driver_service.dart';
import 'package:giaohang_mobile/core/services/realtime_service.dart';
import 'package:giaohang_mobile/features/customer/screens/tracking/tracking_screen.dart';
import 'package:giaohang_mobile/features/customer/screens/tracking/utils/tracking_location_motion.dart';
import 'package:giaohang_mobile/features/delivery_eta/order_eta_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/utraffic_capture_fonts.dart';

const _start = LatLng(11.030862, 106.622104);
const _arrived = LatLng(11.036028, 106.618844);
const _request = (driverId: 'driver-1', orderId: 'order-1');

void main() {
  setUpAll(() async {
    await prepareUtrafficCaptureFonts();
    const loader = SvgAssetLoader(DriverVehicleMarker.assetPath);
    await svg.cache.putIfAbsent(
      loader.cacheKey(null),
      () => loader.loadBytes(null),
    );
  });
  test(
    'a delayed database write must not rewind an active broadcast',
    () async {
      final client = _createClient();
      final realtime = _FakeLocationRealtime(client);
      final container = ProviderContainer(
        overrides: [realtimeServiceProvider.overrideWithValue(realtime)],
      );
      addTearDown(() async {
        container.dispose();
        await client.dispose();
      });
      final subscription = container.listen(
        driverLocationRealtimeProvider(_request),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(driverLocationRealtimeProvider(_request).future);

      realtime.broadcast(_arrived.latitude, _arrived.longitude);
      // This timestamp is the database write time, not the GPS capture time.
      // Network/monitoring delay can make an older coordinate look newer.
      realtime.persisted({
        'current_lat': _start.latitude,
        'current_lng': _start.longitude,
        'location_updated_at': '2026-10-08T14:20:00.800Z',
      });
      expect(container.read(liveDriverLatLngProvider('order-1')), (
        lat: _arrived.latitude,
        lng: _arrived.longitude,
      ));
    },
  );

  test('old drivers update cannot overwrite the broadcast arrival', () async {
    final client = _createClient();
    final realtime = _FakeLocationRealtime(client);
    final container = ProviderContainer(
      overrides: [realtimeServiceProvider.overrideWithValue(realtime)],
    );
    addTearDown(() async {
      container.dispose();
      await client.dispose();
    });
    final subscription = container.listen(
      driverLocationRealtimeProvider(_request),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(driverLocationRealtimeProvider(_request).future);

    realtime.broadcast(_arrived.latitude, _arrived.longitude);
    expect(container.read(liveDriverLatLngProvider('order-1')), (
      lat: _arrived.latitude,
      lng: _arrived.longitude,
    ));
    realtime.persisted({
      'current_lat': _start.latitude,
      'current_lng': _start.longitude,
      'location_updated_at': '2026-10-08T14:15:29Z',
    });

    expect(container.read(liveDriverLatLngProvider('order-1')), (
      lat: _arrived.latitude,
      lng: _arrived.longitude,
    ));
  });

  _testWithMapTiles(
    'five-second samples do not finish moving after 1.1 seconds',
    (tester) async {
      final client = (await tester.runAsync(() async => _createClient()))!;
      final realtime = _FakeLocationRealtime(client);
      final container = _motionContainer(client, realtime);
      final capture = GlobalKey();
      addTearDown(() async {
        container.dispose();
        await tester.runAsync(client.dispose);
      });
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: TrackingScreen(initialTrackingCode: 'GH-10191'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final seed = TrackingLocationMotion.interpolate(_start, _arrived, 0.1);
      final target = TrackingLocationMotion.interpolate(_start, _arrived, 0.6);
      realtime.broadcast(seed.latitude, seed.longitude);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      realtime.sampledAt = realtime.sampledAt.add(const Duration(seconds: 5));
      realtime.broadcast(target.latitude, target.longitude);
      await tester.pump();
      final canvas = tester.widget<TrackingMapCanvas>(
        find.byType(TrackingMapCanvas),
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final early = _markerPosition(tester);
      await tester.pump(const Duration(milliseconds: 1200));
      final later = _markerPosition(tester);
      expect(
        tester.widget<TrackingMapCanvas>(find.byType(TrackingMapCanvas)),
        same(canvas),
      );
      expect(later.latitude, greaterThan(early.latitude + 0.00001));
      expect(later.latitude, lessThan(target.latitude));
      await _capture(tester, capture, 'moving');
      await tester.pump(const Duration(milliseconds: 2700));
      _expectMarkerAt(tester, target);
      await _capture(tester, capture, 'last-sample');
      await tester.pump(const Duration(seconds: 5));
      _expectMarkerAt(tester, target);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  _testWithMapTiles('250ms broadcasts remain smooth across delayed PG events', (
    tester,
  ) async {
    final client = (await tester.runAsync(() async => _createClient()))!;
    final realtime = _FakeLocationRealtime(client);
    var receivedAt = realtime.sampledAt;
    final container = _motionContainer(
      client,
      realtime,
      clock: () => receivedAt,
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(client.dispose);
    });
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TrackingScreen(initialTrackingCode: 'GH-10191')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    realtime.broadcast(_start.latitude, _start.longitude);
    await tester.pump();
    var previous = _markerPosition(tester);
    for (var tick = 1; tick <= 20; tick++) {
      receivedAt = receivedAt.add(const Duration(milliseconds: 250));
      realtime.sampledAt = receivedAt;
      final target = TrackingLocationMotion.interpolate(
        _start,
        _arrived,
        tick / 25,
      );
      realtime.broadcast(target.latitude, target.longitude);
      if (tick % 4 == 0) {
        realtime.persisted({
          'current_lat': _start.latitude,
          'current_lng': _start.longitude,
          'location_updated_at': receivedAt
              .add(const Duration(milliseconds: 800))
              .toIso8601String(),
        });
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      final halfway = _markerPosition(tester);
      expect(halfway.latitude, greaterThan(previous.latitude));
      expect(halfway.latitude, lessThan(target.latitude));
      await tester.pump(const Duration(milliseconds: 125));
      _expectMarkerAt(tester, target);
      previous = _markerPosition(tester);
    }
    // A real turn back with a new Broadcast remains valid; only stale sources
    // are suppressed, not all geographic backwards movement.
    realtime.sampledAt = receivedAt.add(const Duration(seconds: 1));
    realtime.broadcast(_start.latitude, _start.longitude);
    expect(container.read(liveDriverLatLngProvider('order-1')), (
      lat: _start.latitude,
      lng: _start.longitude,
    ));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _testWithMapTiles('a pending profile poll cannot rewind a realtime marker', (
    tester,
  ) async {
    final client = (await tester.runAsync(() async => _createClient()))!;
    final realtime = _FakeLocationRealtime(client);
    final pendingProfile = Completer<DriverModel?>();
    final container = ProviderContainer(
      overrides: [
        orderEtaProvider.overrideWith((ref, id) => const Stream.empty()),
        realtimeServiceProvider.overrideWithValue(realtime),
        driverServiceProvider.overrideWithValue(
          _DelayedDriverService(client, pendingProfile),
        ),
        orderByTrackingCodeProvider.overrideWith((ref, code) async => _order),
        assignedDriverProvider.overrideWith((ref, id) async => _driverAtStart),
        trackedOrderRealtimeProvider.overrideWith((ref, request) async {}),
        orderStatusLogsProvider.overrideWith((ref, id) async => const []),
        orderDeliveryProofsProvider.overrideWith((ref, id) async => const []),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(client.dispose);
    });
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TrackingScreen(initialTrackingCode: 'GH-10191')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    realtime.broadcast(_arrived.latitude, _arrived.longitude);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    _expectMarkerAt(tester, _arrived);

    pendingProfile.complete(_driverAtStart);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(container.read(liveDriverLatLngProvider('order-1')), (
      lat: _arrived.latitude,
      lng: _arrived.longitude,
    ));
    _expectMarkerAt(tester, _arrived);

    // Reopening tracking retains the timestamped live position and freshness.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TrackingScreen(initialTrackingCode: 'GH-10191')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    _expectMarkerAt(tester, _arrived);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'new persisted GPS still advances tracking after broadcast stops',
    () async {
      final client = _createClient();
      final realtime = _FakeLocationRealtime(client);
      var receivedAt = realtime.sampledAt;
      final container = ProviderContainer(
        overrides: [
          realtimeServiceProvider.overrideWithValue(realtime),
          trackingLocationFreshnessProvider.overrideWith(
            (ref, request) =>
                TrackingLocationFreshness(clock: () => receivedAt),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await client.dispose();
      });
      final subscription = container.listen(
        driverLocationRealtimeProvider(_request),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(driverLocationRealtimeProvider(_request).future);
      realtime.broadcast(_arrived.latitude, _arrived.longitude);
      receivedAt = receivedAt.add(const Duration(seconds: 7));
      realtime.persisted({
        'current_lat': 11.035,
        'current_lng': 106.62,
        'location_updated_at': '2026-10-08T14:20:10Z',
      });
      expect(container.read(liveDriverLatLngProvider('order-1')), (
        lat: 11.035,
        lng: 106.62,
      ));

      // An unrelated profile UPDATE can resend the old GPS without a new sample.
      realtime.persisted({
        'current_lat': _start.latitude,
        'current_lng': _start.longitude,
        'updated_at': '2026-10-08T14:21:00Z',
        'location_updated_at': '2026-10-08T14:15:29Z',
      });
      realtime.broadcast(_arrived.latitude, _arrived.longitude);
      expect(container.read(liveDriverLatLngProvider('order-1')), (
        lat: 11.035,
        lng: 106.62,
      ));
    },
  );
}

void _testWithMapTiles(String description, WidgetTesterCallback body) {
  testWidgets(
    description,
    (tester) => http.runWithClient(
      () => body(tester),
      () => MockClient((request) async {
        if (request.url.path.contains('/route/')) {
          return http.Response('{"code":"NoRoute","routes":[]}', 200);
        }
        return http.Response.bytes(
          image.encodePng(image.Image(width: 1, height: 1)),
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    ),
  );
}

SupabaseClient _createClient() => SupabaseClient(
  'http://localhost:54321',
  'test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

void _expectMarkerAt(WidgetTester tester, LatLng expected) {
  final point = _markerPosition(tester);
  expect(point.latitude, closeTo(expected.latitude, 0.000001));
  expect(point.longitude, closeTo(expected.longitude, 0.000001));
}

LatLng _markerPosition(WidgetTester tester) {
  final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
  expect(layer.markers, hasLength(3));
  return layer.markers.last.point;
}

ProviderContainer _motionContainer(
  SupabaseClient client,
  _FakeLocationRealtime realtime, {
  DateTime Function()? clock,
}) => ProviderContainer(
  overrides: [
    if (clock != null)
      trackingLocationFreshnessProvider.overrideWith(
        (ref, request) => TrackingLocationFreshness(clock: clock),
      ),
    orderEtaProvider.overrideWith((ref, id) => const Stream.empty()),
    realtimeServiceProvider.overrideWithValue(realtime),
    driverServiceProvider.overrideWithValue(
      _DelayedDriverService(client, Completer<DriverModel?>()),
    ),
    orderByTrackingCodeProvider.overrideWith((ref, code) async => _order),
    assignedDriverProvider.overrideWith((ref, id) async => _driverAtStart),
    trackedOrderRealtimeProvider.overrideWith((ref, request) async {}),
    orderStatusLogsProvider.overrideWith((ref, id) async => const []),
    orderDeliveryProofsProvider.overrideWith((ref, id) async => const []),
  ],
);

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('TRACKING_MOTION_CAPTURE')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../../.tmp/tracking-motion/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

class _FakeLocationRealtime extends RealtimeService {
  _FakeLocationRealtime(this.client) : super(client: client);

  final SupabaseClient client;
  DateTime sampledAt = DateTime.utc(2026, 10, 8, 14, 20);
  late void Function(double, double) broadcast;
  late void Function(Map<String, dynamic>?) persisted;

  @override
  RealtimeChannel subscribeToOrderDriverBroadcast(
    String orderId,
    void Function(double, double) onLocation, {
    void Function(DateTime?)? onSampleTime,
    void Function(double?)? onSpeed,
  }) {
    broadcast = (lat, lng) {
      onSampleTime?.call(sampledAt);
      onLocation(lat, lng);
    };
    return _UnusedChannel();
  }

  @override
  RealtimeChannel subscribeToDriverLocation(
    String driverId,
    void Function(Map<String, dynamic>?) onLocationChange,
  ) {
    persisted = onLocationChange;
    return _UnusedChannel();
  }

  @override
  Future<void> unsubscribe(String name) async {}
}

class _UnusedChannel implements RealtimeChannel {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DelayedDriverService extends DriverService {
  _DelayedDriverService(SupabaseClient client, this.pending)
    : super(client: client, locationPublisher: _ignorePublish);

  final Completer<DriverModel?> pending;

  @override
  Future<DriverModel?> getDriverForOrder(String orderId) => pending.future;
}

Future<void> _ignorePublish({
  required String driverProfileId,
  required double lat,
  required double lng,
  double? heading,
  double? speed,
}) async {}

final _driverAtStart = DriverModel(
  id: 'profile-1',
  userId: 'driver-1',
  isAvailable: false,
  currentLat: _start.latitude,
  currentLng: _start.longitude,
  updatedAt: DateTime.utc(2026, 10, 8, 14, 15, 29),
  totalDeliveries: 0,
);

final _order = OrderModel(
  id: 'order-1',
  customerId: 'customer-1',
  driverId: 'driver-1',
  status: 'picking_up',
  trackingCode: 'GH-10191',
  pickupAddress: 'Điểm lấy hàng',
  pickupLat: _arrived.latitude,
  pickupLng: _arrived.longitude,
  deliveryAddress: 'Điểm giao hàng',
  deliveryLat: 11.028050,
  deliveryLng: 106.624996,
  createdAt: DateTime.utc(2026, 10, 8),
  deliveryFee: 18000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  updatedAt: DateTime.utc(2026, 10, 8),
);
