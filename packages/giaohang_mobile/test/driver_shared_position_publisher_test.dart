import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:giaohang_mobile/core/location/driver_arrival_fix.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/location/location_ingest_service.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/driver_active_gps_provider.dart';
import 'package:giaohang_mobile/core/providers/driver_position_publisher_provider.dart';
import 'package:giaohang_mobile/core/providers/driver_task_priority_provider.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/core/services/location_service.dart';
import 'package:giaohang_mobile/core/services/realtime_service.dart';

OrderModel _task(String id) => OrderModel.fromJson({
  'id': id,
  'customer_id': 'customer',
  'driver_id': 'driver',
  'status': 'delivering',
  'pickup_address': 'Lấy',
  'pickup_lat': 10.78,
  'pickup_lng': 106.7,
  'delivery_address': 'Giao',
  'delivery_lat': 10.79,
  'delivery_lng': 106.71,
  'tracking_code': id,
  'created_at': '2026-10-30T10:00:00Z',
  'updated_at': '2026-10-30T10:00:00Z',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final delayed in [false, true]) {
    test(
      'one capture is sent to both parcels with its capture time; late responses $delayed',
      () async {
        final wire = _Wire();
        final firstNetwork = Completer<void>();
        if (delayed) wire.gate = firstNetwork;
        final c = _container(wire);
        final keep = [
          c.listen(driverPhysicalPositionProvider, (_, _) {}),
          c.listen(driverArrivalFixProvider, (_, _) {}),
        ];
        await c.read(driverOrdersProvider('driver').future);
        final publisher = c.read(driverPositionPublisherProvider);
        final time = DateTime.now();
        DriverArrivalFix fix(LatLng p, DateTime t) => DriverArrivalFix(
          position: p,
          capturedAt: t,
          accuracy: 8,
          mode: DriverLocationMode.deviceGps,
        );
        final first = publisher.publish(
          driverUserId: 'driver',
          orderId: 'B',
          fix: fix(const LatLng(10.8, 106.72), time),
        );
        await Future<void>.delayed(Duration.zero);
        if (delayed) {
          final second = publisher.publish(
            driverUserId: 'driver',
            orderId: 'A',
            fix: fix(
              const LatLng(10.801, 106.721),
              time.add(const Duration(milliseconds: 1)),
            ),
          );
          expect(
            c.read(driverPhysicalPositionProvider),
            const LatLng(10.801, 106.721),
          );
          firstNetwork.complete();
          await Future.wait([first, second]);
          expect(wire.broadcasts, hasLength(2));
          expect(
            wire.broadcasts.every((r) => r.$2 == const LatLng(10.801, 106.721)),
            isTrue,
          );
        } else {
          await first;
          expect(wire.broadcasts, hasLength(2));
          expect(wire.broadcasts.map((r) => r.$1).toSet(), {'A', 'B'});
          expect(
            wire.broadcasts.every(
              (r) => r.$2 == const LatLng(10.8, 106.72) && r.$3 == time,
            ),
            isTrue,
          );
        }
        expect(
          await publisher.publish(
            driverUserId: 'driver',
            orderId: 'B',
            fix: fix(
              const LatLng(1, 2),
              time.subtract(const Duration(seconds: 1)),
            ),
          ),
          isFalse,
        );
        final position = c.read(driverPhysicalPositionProvider);
        publisher.seedLastKnown(const LatLng(1, 2));
        expect(c.read(driverPhysicalPositionProvider), position);
        for (final sub in keep) {
          sub.close();
        }
        c.dispose();
      },
    );
  }
  test(
    'one live GPS subscription survives B to A and map close; invalid captures do not move it',
    () async {
      final wire = _Wire();
      final gps = _Gps();
      final c = _container(wire, gps: gps);
      final physical = c.listen(driverPhysicalPositionProvider, (_, _) {});
      final fix = c.listen(driverArrivalFixProvider, (_, _) {});
      await c.read(driverOrdersProvider('driver').future);
      c.read(driverPriorityOrderIdProvider.notifier).state = 'B';
      final tracking = c.listen(driverActiveGpsProvider('driver'), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      c.read(activeDriverNavigationOrderProvider.notifier).state = 'B';
      await c.pump();
      c.read(driverPriorityOrderIdProvider.notifier).state = 'A';
      c.read(activeDriverNavigationOrderProvider.notifier).state = 'A';
      await c.pump();
      gps.emit(_position(10.801, accuracy: 8));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(wire.ingests.last.$1, 'A');
      expect(physical.read(), const LatLng(10.801, 106.72));
      gps.emit(_position(20, accuracy: 100));
      gps.emit(_position(21, age: const Duration(minutes: 2)));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(physical.read(), const LatLng(10.801, 106.72));
      c.read(activeDriverNavigationOrderProvider.notifier).state = null;
      await c.pump();
      expect(gps.starts, 1);
      expect(gps.stops, 0);
      expect(wire.broadcasts.map((r) => r.$1).toSet(), {'A', 'B'});
      tracking.close();
      physical.close();
      fix.close();
      c.dispose();
      expect(gps.stops, 1);
    },
  );
  test(
    'a stopped demo for B cannot publish over the chosen redelivery A',
    () async {
      final wire = _Wire();
      final c = _container(wire);
      final physical = c.listen(driverPhysicalPositionProvider, (_, _) {});
      final keep = c.listen(driverArrivalFixProvider, (_, _) {});
      final priority = c.listen(driverPriorityOrderIdProvider, (_, _) {});
      await c.read(driverOrdersProvider('driver').future);
      c.read(driverLocationModeProvider.notifier).state =
          DriverLocationMode.demoCurrentPosition;
      c.read(driverPriorityOrderIdProvider.notifier).state = 'A';
      final publisher = c.read(driverPositionPublisherProvider);
      final fix = DriverArrivalFix(
        position: const LatLng(10.8, 106.72),
        capturedAt: DateTime.now(),
        accuracy: 0,
        mode: DriverLocationMode.demoCurrentPosition,
        simulated: true,
      );
      expect(
        await publisher.publish(driverUserId: 'driver', orderId: 'B', fix: fix),
        isFalse,
      );
      expect(physical.read(), isNull);
      expect(
        await publisher.publish(driverUserId: 'driver', orderId: 'A', fix: fix),
        isTrue,
      );
      expect(physical.read(), fix.position);
      physical.close();
      keep.close();
      priority.close();
      c.dispose();
    },
  );
}

ProviderContainer _container(_Wire wire, {_Gps? gps}) => ProviderContainer(
  overrides: [
    driverLocationModeProvider.overrideWith(
      (ref) => DriverLocationMode.deviceGps,
    ),
    locationIngestServiceProvider.overrideWithValue(wire),
    realtimeServiceProvider.overrideWithValue(wire),
    driverOrdersProvider(
      'driver',
    ).overrideWith((ref) => Stream.value([_task('A'), _task('B')])),
    driverByUserIdProvider('driver').overrideWith((ref) async => null),
    if (gps != null) locationServiceProvider.overrideWithValue(gps),
  ],
);
Position _position(
  double lat, {
  double accuracy = 8,
  Duration age = Duration.zero,
}) => Position(
  latitude: lat,
  longitude: 106.72,
  timestamp: DateTime.now().subtract(age),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _Gps extends LocationService {
  int starts = 0, stops = 0;
  late void Function(Position) emit;
  @override
  Future<Position?> getCurrentPosition() async => _position(10.8);
  @override
  void startTracking({
    required void Function(Position) onPosition,
    void Function(String)? onError,
    int distanceFilterMeters = 10,
  }) {
    starts++;
    emit = onPosition;
  }

  @override
  void stopTracking() {
    stops++;
  }
}

class _Wire implements LocationIngestService, RealtimeService {
  final ingests = <(String?, LatLng)>[];
  final broadcasts = <(String, LatLng, DateTime?)>[];
  Completer<void>? gate;
  @override
  Future<void> ingest({
    String? driverProfileId,
    String? driverUserId,
    String? orderId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? capturedAt,
    LatLng? monitoringPosition,
    bool force = false,
    bool prioritySync = false,
    LocationIngestCoordinateSpace coordinateSpace =
        LocationIngestCoordinateSpace.rawGps,
  }) async {
    ingests.add((orderId, LatLng(lat, lng)));
    if (ingests.length == 1 && gate != null) await gate!.future;
  }

  @override
  Future<void> broadcastDriverLocation({
    required String orderId,
    required double lat,
    required double lng,
    double? speedKmh,
    DateTime? sampledAt,
  }) async {
    broadcasts.add((orderId, LatLng(lat, lng), sampledAt));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
