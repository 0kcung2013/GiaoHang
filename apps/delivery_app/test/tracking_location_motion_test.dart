import 'package:delivery_app/features/customer/screens/tracking/utils/tracking_location_motion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('TrackingLocationMotion', () {
    test('keeps polling dormant while realtime is fresh', () {
      final now = DateTime(2026, 8, 7, 15, 0, 0);

      expect(
        TrackingLocationMotion.shouldPollFallback(
          lastRealtimeAt: now.subtract(const Duration(seconds: 4)),
          now: now,
        ),
        isFalse,
      );
      expect(
        TrackingLocationMotion.shouldPollFallback(
          lastRealtimeAt: now.subtract(const Duration(seconds: 7)),
          now: now,
        ),
        isTrue,
      );
    });

    test(
      'interpolates the driver marker instead of jumping to the next GPS point',
      () {
        const from = LatLng(10.7800, 106.6750);
        const to = LatLng(10.7820, 106.6790);

        expect(TrackingLocationMotion.interpolate(from, to, 0.0), from);
        expect(TrackingLocationMotion.interpolate(from, to, 1.0), to);
        final middle = TrackingLocationMotion.interpolate(from, to, 0.5);
        expect(middle.latitude, closeTo(10.7810, 0.000001));
        expect(middle.longitude, closeTo(106.6770, 0.000001));
      },
    );

    test('snaps a GPS point to the nearest route segment', () {
      const route = [
        LatLng(0.0, 0.0),
        LatLng(0.0, 0.001),
        LatLng(0.001, 0.001),
      ];

      final projection = TrackingLocationMotion.projectOntoRoute(
        const LatLng(0.0002, 0.0004),
        route,
      );

      expect(projection, isNotNull);
      expect(projection!.point.latitude, closeTo(0.0, 0.000001));
      expect(projection.point.longitude, closeTo(0.0004, 0.000001));
      expect(projection.bearingDegrees, closeTo(90.0, 0.01));
    });

    test('interpolates the driver marker along route geometry', () {
      const route = [
        LatLng(0.0, 0.0),
        LatLng(0.0, 0.001),
        LatLng(0.001, 0.001),
      ];
      final from = TrackingLocationMotion.projectOntoRoute(
        const LatLng(0.0, 0.0),
        route,
      );
      final to = TrackingLocationMotion.projectOntoRoute(
        const LatLng(0.001, 0.001),
        route,
      );

      final middle = TrackingLocationMotion.interpolateAlongRoute(
        route: route,
        from: from!,
        to: to!,
        progress: 0.75,
      );

      expect(middle.latitude, closeTo(0.0005, 0.000001));
      expect(middle.longitude, closeTo(0.001, 0.000001));
    });
  });
}
