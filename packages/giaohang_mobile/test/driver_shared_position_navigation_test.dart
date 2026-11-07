import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/driver_nav_session_provider.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/location/driver_arrival_fix.dart';
import 'package:giaohang_mobile/core/services/osrm_service.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/data/driver_navigation_routing_provider.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_navigation_map.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/utils/driver_navigation_route_logic.dart';
import 'support/return_map_test_tiles.dart';
import 'helpers/utraffic_capture_fonts.dart';

OrderModel task(String id, LatLng destination) => OrderModel.fromJson({
  'id': id,
  'customer_id': 'customer',
  'driver_id': 'driver',
  'status': 'delivering',
  'pickup_address': 'Điểm lấy',
  'pickup_lat': 10.78,
  'pickup_lng': 106.70,
  'delivery_address': 'Điểm giao $id',
  'delivery_lat': destination.latitude,
  'delivery_lng': destination.longitude,
  'tracking_code': id,
  if (id == 'A')
    'delivery_hold': {
      'state': 'resumed',
      'started_at': '2026-10-30T10:00:00Z',
      'until': '2026-10-30T10:15:00Z',
    },
  'created_at': '2026-10-30T10:00:00Z',
  'updated_at': '2026-10-30T10:00:00Z',
});

void main() {
  setUpAll(ReturnMapTestTiles.prepare);
  setUpAll(prepareUtrafficCaptureFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  const x = LatLng(10.80, 106.72);
  const destinationA = LatLng(10.78, 106.70);
  const destinationB = LatLng(10.82, 106.74);
  for (final mode in [
    DriverLocationMode.deviceGps,
    DriverLocationMode.demoCurrentPosition,
  ]) {
    testWidgets(
      'switch B to A routes from shared X, rejects late B and never restores parcel coordinates: $mode',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        final routing = _PendingRouting();
        final sessions = DriverNavSessionsNotifier();
        await sessions.hydrate();
        await sessions.upsert(
          DriverNavSession(
            orderId: 'A',
            status: 'delivering',
            lat: destinationA.latitude,
            lng: destinationA.longitude,
            locationMode: mode,
            arrivedAtTarget: true,
            routeCompleted: true,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            driverNavigationTilesProvider.overrideWith(
              (ref) => ReturnMapTestTiles(),
            ),
            driverNavigationRoutingProvider.overrideWithValue(routing),
            driverLocationModeProvider.overrideWith((ref) => mode),
            driverNavSessionsProvider.overrideWith((ref) => sessions),
            driverPhysicalPositionProvider.overrideWith((ref) => x),
            driverArrivalFixProvider.overrideWith(
              (ref) => DriverArrivalFix(
                position: x,
                capturedAt: DateTime.now(),
                accuracy: 8,
                mode: mode,
              ),
            ),
            driverByUserIdProvider('driver').overrideWith((ref) async => null),
            driverOrdersProvider('driver').overrideWith(
              (ref) => Stream.value([
                task('A', destinationA),
                task('B', destinationB),
              ]),
            ),
          ],
        );
        final physical = container.listen(
          driverPhysicalPositionProvider,
          (_, _) {},
        );
        Widget page(String id, LatLng destination) => RepaintBoundary(
          key: capture,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: DriverNavigationScreen(order: task(id, destination)),
            ),
          ),
        );
        await tester.pumpWidget(page('B', destinationB));
        await tester.pump(const Duration(milliseconds: 10));
        expect(routing.requests.last.points, [x, destinationB]);
        final b = routing.requests.last;
        await tester.tap(find.byKey(const ValueKey('driver-open-map')));
        await tester.pump();
        const moved = LatLng(10.801, 106.721);
        container.read(driverPhysicalPositionProvider.notifier).state = moved;
        await tester.pumpWidget(page('A', destinationA));
        await tester.pump(const Duration(milliseconds: 10));
        expect(routing.requests.last.points, [moved, destinationA]);
        final a = routing.requests.last;
        var map = tester.widget<DriverNavigationMap>(
          find.byType(DriverNavigationMap),
        );
        expect(map.driverPosition, moved);
        expect(map.routePoints, isNull);
        expect(map.status, 'Đang tìm đường');
        b.result.complete(
          OsrmRouteResult(
            points: b.points,
            distanceMeters: 1000,
            durationSeconds: 100,
          ),
        );
        await tester.pump();
        map = tester.widget<DriverNavigationMap>(
          find.byType(DriverNavigationMap),
        );
        expect(
          map.routePoints,
          isNull,
          reason: 'Late B route must not appear on A',
        );
        a.result.complete(
          OsrmRouteResult(
            points: a.points,
            distanceMeters: 1000,
            durationSeconds: 100,
          ),
        );
        await tester.pump();
        map = tester.widget<DriverNavigationMap>(
          find.byType(DriverNavigationMap),
        );
        expect(map.driverPosition, moved);
        expect(map.routePoints!.last, destinationA);
        expect(map.otherDestination, destinationB);
        expect(container.read(driverPhysicalPositionProvider), moved);
        if (mode == DriverLocationMode.deviceGps) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('driver-vehicle-marker')),
            findsOneWidget,
          );
          final markerCenter = tester.getCenter(
            find.byKey(const Key('driver-vehicle-marker')),
          );
          expect(markerCenter.dx, inInclusiveRange(0, 390));
          expect(markerCenter.dy, inInclusiveRange(0, 844));
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '../../artifacts/driver_shared_gps_route_a.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        for (final item in [('B', destinationB), ('A', destinationA)]) {
          await tester.pumpWidget(page(item.$1, item.$2));
          await tester.pump(const Duration(milliseconds: 10));
          expect(routing.requests.last.points, [moved, item.$2]);
          final request = routing.requests.last;
          request.result.complete(
            OsrmRouteResult(
              points: request.points,
              distanceMeters: 1000,
              durationSeconds: 100,
            ),
          );
          await tester.pump();
          map = tester.widget<DriverNavigationMap>(
            find.byType(DriverNavigationMap),
          );
          expect(map.driverPosition, moved);
          expect(map.routePoints!.last, item.$2);
        }
        const offRoute = LatLng(10.811, 106.711);
        container.read(driverPhysicalPositionProvider.notifier).state =
            offRoute;
        await tester.pump();
        map = tester.widget<DriverNavigationMap>(
          find.byType(DriverNavigationMap),
        );
        expect(map.driverPosition, offRoute);
        expect(map.routePoints, isNull);
        expect(routing.requests.last.points, [offRoute, destinationA]);
        routing.requests.last.result.complete(null);
        await tester.pump();
        map = tester.widget<DriverNavigationMap>(
          find.byType(DriverNavigationMap),
        );
        expect(
          map.routePoints,
          isNull,
          reason: 'No straight-line route may replace a failed road route',
        );
        expect(map.status, 'Chưa tìm được đường · Đang thử lại');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
        for (final request in routing.requests) {
          if (!request.result.isCompleted) request.result.complete(null);
        }
        physical.close();
        container.dispose();
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
  testWidgets(
    'cold start with parcel coordinates waits for an actual driver capture',
    (tester) async {
      final routing = _PendingRouting();
      final sessions = DriverNavSessionsNotifier();
      await sessions.hydrate();
      await sessions.upsert(
        DriverNavSession(
          orderId: 'A',
          status: 'delivering',
          lat: destinationA.latitude,
          lng: destinationA.longitude,
          locationMode: DriverLocationMode.deviceGps,
          arrivedAtTarget: true,
          routeCompleted: true,
        ),
      );
      final c = ProviderContainer(
        overrides: [
          driverNavigationTilesProvider.overrideWith(
            (ref) => ReturnMapTestTiles(),
          ),
          driverNavigationRoutingProvider.overrideWithValue(routing),
          driverNavSessionsProvider.overrideWith((ref) => sessions),
          driverByUserIdProvider('driver').overrideWith((ref) async => null),
          driverOrdersProvider(
            'driver',
          ).overrideWith((ref) => const Stream.empty()),
        ],
      );
      final fix = c.listen(driverArrivalFixProvider, (_, _) {});
      final physical = c.listen(driverPhysicalPositionProvider, (_, _) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: DriverNavigationScreen(order: task('A', destinationA)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byKey(const ValueKey('driver-open-map')));
      await tester.pump();
      var map = tester.widget<DriverNavigationMap>(
        find.byType(DriverNavigationMap),
      );
      expect(map.driverPosition, isNull);
      expect(map.status, 'Đang cập nhật vị trí');
      expect(routing.requests, isEmpty);
      c.read(driverArrivalFixProvider.notifier).state = DriverArrivalFix(
        position: x,
        capturedAt: DateTime.now(),
        accuracy: 8,
        mode: DriverLocationMode.deviceGps,
      );
      c.read(driverPhysicalPositionProvider.notifier).state = x;
      await tester.pump();
      expect(routing.requests.last.points, [x, destinationA]);
      final request = routing.requests.last;
      request.result.complete(
        OsrmRouteResult(
          points: request.points,
          distanceMeters: 1000,
          durationSeconds: 100,
        ),
      );
      await tester.pump();
      map = tester.widget<DriverNavigationMap>(
        find.byType(DriverNavigationMap),
      );
      expect(map.driverPosition, x);
      expect(map.routePoints!.last, destinationA);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      fix.close();
      physical.close();
      c.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  testWidgets('B to A keeps marker at X even when old A polyline is elsewhere', (
    tester,
  ) async {
    final controller = MapController();
    final oldA = [
      const LatLng(10.8002, 106.719),
      const LatLng(10.8002, 106.721),
    ];
    for (final item in [
      (task('B', destinationB), [x, destinationB]),
      (task('A', destinationA), oldA),
      (task('A', destinationA), [x, destinationA]),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverNavigationMap(
              mapController: controller,
              order: item.$1,
              center: x,
              tileProvider: ReturnMapTestTiles(),
              routePoints: item.$2,
              driverPosition: x,
            ),
          ),
        ),
      );
      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(
        layer.markers.last.point,
        x,
        reason:
            'Changing the parcel or route must never snap the driver to that route',
      );
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 100));
  });
  test(
    'a long distance never substitutes pickup for the real route origin',
    () {
      const far = LatLng(21.03, 105.85);
      expect(
        DriverNavigationRouteLogic.buildWaypoints(
          order: task('A', destinationA),
          driverPosition: far,
        ),
        [far, destinationA],
      );
    },
  );
}

class _PendingRouting extends OsrmService {
  final requests =
      <({List<LatLng> points, Completer<OsrmRouteResult?> result})>[];
  @override
  Future<OsrmRouteResult?> getRouteWithWaypoints({
    required List<LatLng> waypoints,
  }) {
    final result = Completer<OsrmRouteResult?>();
    requests.add((points: waypoints.toList(), result: result));
    return result.future;
  }
}
