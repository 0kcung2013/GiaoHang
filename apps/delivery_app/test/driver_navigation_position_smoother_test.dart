import 'package:delivery_app/features/driver/screens/navigation/utils/driver_navigation_position_smoother.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('DriverNavigationPositionSmoother', () {
    test('ignores small GPS jitter', () {
      const previous = LatLng(10.0, 106.0);
      final result = DriverNavigationPositionSmoother.smooth(
        previous: previous,
        next: const LatLng(10.00001, 106.0),
      );

      expect(result, previous);
    });

    test('eases ordinary GPS movement instead of jumping to it', () {
      const previous = LatLng(10.0, 106.0);
      final result = DriverNavigationPositionSmoother.smooth(
        previous: previous,
        next: const LatLng(10.0001, 106.0),
      );

      expect(result.latitude, greaterThan(previous.latitude));
      expect(result.latitude, lessThan(10.0001));
    });
  });
}
