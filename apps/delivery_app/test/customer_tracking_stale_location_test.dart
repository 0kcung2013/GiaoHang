import 'dart:async';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:delivery_app/core/services/driver_service.dart';
import 'package:delivery_app/core/services/realtime_service.dart';
import 'package:delivery_app/features/customer/screens/tracking/tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _start = LatLng(11.030862, 106.622104);
const _arrived = LatLng(11.036028, 106.618844);
const _request = (driverId: 'driver-1', orderId: 'order-1');

void main() {
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

  _testWithMapTiles('a pending profile poll cannot rewind a realtime marker', (
    tester,
  ) async {
    final client = (await tester.runAsync(() async => _createClient()))!;
    final realtime = _FakeLocationRealtime(client);
    final pendingProfile = Completer<DriverModel?>();
    final container = ProviderContainer(
      overrides: [
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
    await tester.pump(const Duration(milliseconds: 1200));
    _expectMarkerAt(tester, _arrived);

    pendingProfile.complete(_driverAtStart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

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
    await tester.pump(const Duration(milliseconds: 1200));
    _expectMarkerAt(tester, _arrived);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'new persisted GPS still advances tracking after broadcast stops',
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
  final point = tester
      .widget<TrackingMapCanvas>(find.byType(TrackingMapCanvas))
      .driverPosition!;
  expect(point.latitude, closeTo(expected.latitude, 0.000001));
  expect(point.longitude, closeTo(expected.longitude, 0.000001));
}

class _FakeLocationRealtime extends RealtimeService {
  _FakeLocationRealtime(this.client) : super(client: client);

  final SupabaseClient client;
  late void Function(double, double) broadcast;
  late void Function(Map<String, dynamic>?) persisted;

  @override
  RealtimeChannel subscribeToOrderDriverBroadcast(
    String orderId,
    void Function(double, double) onLocation, {
    void Function(DateTime?)? onSampleTime,
  }) {
    broadcast = (lat, lng) {
      onSampleTime?.call(DateTime.utc(2026, 10, 8, 14, 20));
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
