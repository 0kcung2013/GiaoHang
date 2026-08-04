import 'package:delivery_app/features/driver/screens/navigation/utils/driver_navigation_route_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('DriverNavigationRouteLogic navigation camera', () {
    test('keeps northbound travel pointing to the top of the screen', () {
      final rotation = DriverNavigationRouteLogic.navigationRotationDegrees(
        driverPosition: const LatLng(10, 106),
        routePoints: const [LatLng(10, 106), LatLng(10.002, 106)],
      );

      expect(rotation, closeTo(0, 0.1));
    });

    test('rotates an eastbound route so travel remains heading-up', () {
      final rotation = DriverNavigationRouteLogic.navigationRotationDegrees(
        driverPosition: const LatLng(10, 106),
        routePoints: const [LatLng(10, 106), LatLng(10, 106.002)],
      );

      expect(rotation, closeTo(270, 0.5));
    });
  });
}
