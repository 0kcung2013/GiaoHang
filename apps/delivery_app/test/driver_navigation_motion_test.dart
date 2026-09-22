import 'package:delivery_app/features/driver/screens/navigation/utils/driver_navigation_motion.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_map.dart';
import 'package:delivery_app/core/utils/delivery_map_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('DriverNavigationMotion', () {
    test('interpolates the marker halfway between two GPS samples', () {
      final position = DriverNavigationMotion.interpolate(
        const LatLng(10.7600, 106.6600),
        const LatLng(10.7620, 106.6640),
        0.5,
      );

      expect(position.latitude, closeTo(10.7610, 0.000001));
      expect(position.longitude, closeTo(106.6620, 0.000001));
    });

    test('clamps animation progress outside the valid range', () {
      const from = LatLng(10.7600, 106.6600);
      const to = LatLng(10.7620, 106.6640);

      expect(DriverNavigationMotion.interpolate(from, to, -1), from);
      expect(DriverNavigationMotion.interpolate(from, to, 2), to);
    });

    test('limits each simulation tick by the configured road speed', () {
      const start = LatLng(10, 106);
      const route = [start, LatLng(10.002, 106)];

      final step = DriverNavigationMotion.advanceAlongRoute(
        route: route,
        current: start,
        nextRouteIndex: 1,
        maxDistanceMeters: 1.525,
      );

      final movedMeters = const Distance(
        roundResult: false,
      ).as(LengthUnit.Meter, start, step.position);
      expect(movedMeters, closeTo(1.525, 0.02));
      expect(step.nextRouteIndex, 1);
      expect(step.reachedEnd, isFalse);
    });

    test('simulation progress survives route snapping between ticks', () {
      const start = LatLng(10, 106);
      const route = [start, LatLng(10.002, 106)];
      var publishedPosition = start;
      var nextRouteIndex = 1;

      for (var tick = 0; tick < 4; tick++) {
        final step = DriverNavigationMotion.advanceAlongRoute(
          route: route,
          current: publishedPosition,
          nextRouteIndex: nextRouteIndex,
          maxDistanceMeters: 1.525,
        );
        nextRouteIndex = step.nextRouteIndex;
        publishedPosition = DeliveryMapUtils.snapToRoute(
          fullRoute: route,
          current: step.position,
        );
      }

      final movedMeters = const Distance(
        roundResult: false,
      ).as(LengthUnit.Meter, start, publishedPosition);
      expect(movedMeters, closeTo(6.1, 0.1));
    });

    test('remaining route starts at the projected point between vertices', () {
      const route = [
        LatLng(0.0, 0.0),
        LatLng(0.0, 0.001),
        LatLng(0.001, 0.001),
      ];

      final remaining = DeliveryMapUtils.remainingRoute(
        fullRoute: route,
        current: const LatLng(0.0002, 0.0004),
      );

      expect(remaining.first.latitude, closeTo(0.0, 0.000001));
      expect(remaining.first.longitude, closeTo(0.0004, 0.000001));
      expect(remaining[1], route[1]);
      expect(
        DeliveryMapUtils.routeBearing(route: route, current: remaining.first),
        closeTo(90.0, 0.01),
      );
    });

    test('driver map removes the travelled part of the polyline', () {
      const route = [
        LatLng(0.0, 0.0),
        LatLng(0.0, 0.001),
        LatLng(0.001, 0.001),
      ];

      final remaining = DriverNavigationMap.remainingRouteFor(
        routePoints: route,
        driverPosition: const LatLng(0.0002, 0.0004),
      )!;

      expect(remaining.first.latitude, closeTo(0.0, 0.000001));
      expect(remaining.first.longitude, closeTo(0.0004, 0.000001));
      expect(remaining, isNot(contains(route.first)));
      expect(remaining.last, route.last);
    });

    test('driver map bearing follows the next segment at a route turn', () {
      const route = [
        LatLng(0.0, 0.0),
        LatLng(0.0, 0.001),
        LatLng(0.001, 0.001),
      ];

      final remaining = DriverNavigationMap.remainingRouteFor(
        routePoints: route,
        driverPosition: route[1],
      )!;
      final bearing = DeliveryMapUtils.routeBearing(
        route: remaining,
        current: route[1],
      );

      expect(bearing, closeTo(0, 0.01));
    });

    test('forward bearing smooths a tiny connector before a turn', () {
      const driver = LatLng(10, 106);
      const route = [driver, LatLng(10, 106.00005), LatLng(10.001, 106.00005)];

      final bearing = DeliveryMapUtils.forwardRouteBearing(
        route: route,
        current: driver,
        lookAheadMeters: 24,
      );

      expect(bearing, greaterThan(0));
      expect(bearing, lessThan(25));
    });

    test('marker animation follows route geometry around a bend', () {
      const route = [
        LatLng(0.0, 0.0),
        LatLng(0.0, 0.001),
        LatLng(0.001, 0.001),
      ];

      final middle = DeliveryMapUtils.interpolateAlongRoute(
        route: route,
        from: route.first,
        to: route.last,
        progress: 0.75,
      );

      expect(middle.latitude, closeTo(0.0005, 0.000001));
      expect(middle.longitude, closeTo(0.001, 0.000001));
    });
  });
}
