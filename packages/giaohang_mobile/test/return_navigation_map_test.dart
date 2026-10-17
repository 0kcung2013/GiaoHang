import 'dart:math' as math;

import 'package:giaohang_mobile/core/widgets/delivery_map_markers.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/utils/driver_navigation_route_logic.dart';
import 'package:giaohang_mobile/features/returns/widgets/return_navigation_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/return_map_test_tiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ReturnMapTestTiles.prepare);
  const origin = LatLng(10.775, 106.680);

  for (final scenario in const [
    (destination: LatLng(10.777, 106.682), viewport: Size(320, 568)),
    (destination: LatLng(10.775, 106.678), viewport: Size(390, 844)),
  ]) {
    testWidgets(
      'return vehicle faces forward towards ${scenario.destination}',
      (tester) async {
        tester.view.physicalSize = scenario.viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = MapController();
        final destination = scenario.destination;
        final route = [origin, destination];

        await _pumpReturnMap(
          tester,
          controller: controller,
          destination: destination,
          position: origin,
          route: route,
        );
        DriverNavigationRouteLogic.followRouteCamera(
          controller: controller,
          driverPosition: origin,
          routePoints: route,
          fallbackTarget: destination,
        );
        await tester.pump();

        expect(find.byType(DriverVehicleMarker), findsOneWidget);
        expect(_screenBearing(tester), closeTo(0, 1));

        final nextPosition = LatLng(
          (origin.latitude + destination.latitude) / 2,
          (origin.longitude + destination.longitude) / 2,
        );
        final updatedRoute = [
          nextPosition,
          LatLng(nextPosition.latitude + 0.001, nextPosition.longitude - 0.001),
          destination,
        ];
        await _pumpReturnMap(
          tester,
          controller: controller,
          destination: destination,
          position: nextPosition,
          route: updatedRoute,
        );
        await tester.pump(const Duration(seconds: 2));
        DriverNavigationRouteLogic.followRouteCamera(
          controller: controller,
          driverPosition: nextPosition,
          routePoints: updatedRoute,
          fallbackTarget: destination,
        );
        await tester.pump();

        expect(_screenBearing(tester), closeTo(0, 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }

  testWidgets('return vehicle remains visible before the route loads', (
    tester,
  ) async {
    final controller = MapController();
    for (final route in <List<LatLng>?>[
      null,
      [],
      [origin],
    ]) {
      await _pumpReturnMap(
        tester,
        controller: controller,
        destination: const LatLng(10.777, 106.682),
        position: origin,
        route: route,
      );

      expect(find.byType(DriverVehicleMarker), findsOneWidget);
      expect(_screenBearing(tester), closeTo(0, 1));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

Future<void> _pumpReturnMap(
  WidgetTester tester, {
  required MapController controller,
  required LatLng destination,
  required LatLng position,
  required List<LatLng>? route,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReturnNavigationMap(
        controller: controller,
        destination: destination,
        position: position,
        route: route,
        tileProvider: ReturnMapTestTiles(),
      ),
    ),
  );
}

/// Measure the rendered vehicle's front after both marker and camera rotation.
double _screenBearing(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(
    find.byKey(const Key('driver-vehicle-marker')),
  );
  final center = box.localToGlobal(box.size.center(Offset.zero));
  final front = box.localToGlobal(Offset(box.size.width / 2, 0));
  final direction = front - center;
  return math.atan2(direction.dx, -direction.dy) * 180 / math.pi;
}
