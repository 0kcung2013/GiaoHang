import 'package:delivery_app/features/returns/utils/return_navigation_tracker.dart';
import 'package:delivery_app/features/returns/widgets/return_navigation_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/return_map_test_tiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ReturnMapTestTiles.prepare);
  testWidgets('return simulation moves at road speed on a sparse polyline', (
    tester,
  ) async {
    final tracker = ReturnNavigationTracker();
    addTearDown(tracker.dispose);
    const route = [LatLng(10, 106), LatLng(10.002, 106)];
    final positions = <LatLng>[];
    tracker.startSimulation(
      route: route,
      currentPosition: route.first,
      canMove: () => true,
      onPosition: positions.add,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(positions, isNotEmpty);
    final traveled = const Distance(
      roundResult: false,
    ).as(LengthUnit.Meter, route.first, positions.last);
    expect(
      traveled,
      closeTo(30, 0.5),
      reason: 'Two seconds must move 30 m, rather than jump to an OSRM vertex.',
    );
    expect(
      positions.length,
      2,
      reason: 'Keep the GPS sample cadence; smoothness belongs to rendering.',
    );
    await tracker.dispose();
  });

  testWidgets('return marker animates between incoming position samples', (
    tester,
  ) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    const route = [LatLng(10, 106), LatLng(10.002, 106)];
    Future<void> show(LatLng position) => tester.pumpWidget(
      MaterialApp(
        home: ReturnNavigationMap(
          controller: controller,
          destination: route.last,
          position: position,
          route: route,
          tileProvider: ReturnMapTestTiles(),
        ),
      ),
    );
    await show(route.first);
    await show(route.last);
    expect(
      _driverPosition(tester),
      route.first,
      reason: 'A new GPS sample must not teleport the rendered marker.',
    );
    await tester.pump(const Duration(milliseconds: 125));
    final halfway = _driverPosition(tester);
    expect(halfway.latitude, greaterThan(route.first.latitude));
    expect(halfway.latitude, lessThan(route.last.latitude));
    await tester.pump(const Duration(seconds: 2));
    expect(
      _driverPosition(tester).latitude,
      closeTo(route.last.latitude, 0.000001),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('return marker follows the polyline around a bend', (
    tester,
  ) async {
    final controller = MapController();
    const route = [LatLng(0, 0), LatLng(0, 0.001), LatLng(0.001, 0.001)];
    await _show(tester, controller, route, route.first);
    await _show(tester, controller, route, route.last);
    await tester.pump(const Duration(milliseconds: 750));
    final position = _driverPosition(tester);
    expect(position.longitude, closeTo(0.001, 0.000001));
    expect(position.latitude, closeTo(0.0005, 0.000001));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('a newer sample continues from the rendered position', (
    tester,
  ) async {
    final controller = MapController();
    const route = [LatLng(10, 106), LatLng(10.002, 106)];
    await _show(tester, controller, route, route.first);
    await _show(tester, controller, route, const LatLng(10.001, 106));
    await tester.pump(const Duration(milliseconds: 400));
    final before = _driverPosition(tester);
    await _show(tester, controller, route, route.last);
    expect(_driverPosition(tester).latitude, closeTo(before.latitude, 1e-9));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_driverPosition(tester).latitude, greaterThan(before.latitude));
    expect(_driverPosition(tester).latitude, lessThan(route.last.latitude));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  for (final viewport in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets(
      'camera follows the same rendered position at ${viewport.width}',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = MapController();
        const route = [LatLng(10, 106), LatLng(10.002, 106)];
        await _show(tester, controller, route, route.first, follow: true);
        await tester.pumpAndSettle();
        final initialCenter = _screenDriverCenter(tester);
        await _show(tester, controller, route, route.last, follow: true);
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 200));
          final center = _screenDriverCenter(tester);
          expect(center.dx, closeTo(initialCenter.dx, 0.5));
          expect(
            center.dy,
            closeTo(initialCenter.dy, 0.5),
            reason: 'The camera must not jump ahead to the raw GPS target.',
          );
        }
        await _show(tester, controller, route, route.last);
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          _driverPosition(tester).latitude,
          closeTo(route.last.latitude, 1e-9),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }

  testWidgets('camera keeps the final road heading when the vehicle stops', (
    tester,
  ) async {
    final controller = MapController();
    const route = [LatLng(10, 106), LatLng(10.002, 106.002)];
    await _show(tester, controller, route, route.first, follow: true);
    await tester.pumpAndSettle();
    final initialHeading = controller.camera.rotation;
    expect(initialHeading, isNot(closeTo(0, 1)));
    await _show(tester, controller, route, route.last, follow: true);
    await tester.pump(const Duration(seconds: 1));
    expect(
      controller.camera.rotation,
      closeTo(initialHeading, 0.01),
      reason: 'Arriving must not suddenly rotate the camera back to north.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

Future<void> _show(
  WidgetTester tester,
  MapController controller,
  List<LatLng> route,
  LatLng position, {
  bool follow = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: ReturnNavigationMap(
      controller: controller,
      destination: route.last,
      position: position,
      route: route,
      followPosition: follow,
      tileProvider: ReturnMapTestTiles(),
    ),
  ),
);

Offset _screenDriverCenter(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(
    find.byKey(const Key('driver-vehicle-marker')),
  );
  return box.localToGlobal(box.size.center(Offset.zero));
}

LatLng _driverPosition(WidgetTester tester) =>
    tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point;
