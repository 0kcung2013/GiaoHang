import 'package:delivery_app/features/driver/screens/navigation/utils/driver_navigation_motion.dart';
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
  });
}
