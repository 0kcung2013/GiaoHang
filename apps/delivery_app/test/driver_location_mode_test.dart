import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('DriverLocationMode', () {
    test('defaults the app session to device GPS', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(driverLocationModeProvider),
        DriverLocationMode.deviceGps,
      );
    });

    test('demo mode maps raw GPS to the fixed point for the driver email', () {
      final resolved = DriverLocationMode.demoHcm.resolveRawGps(
        email: 'taixe@gmail.com',
        lat: 21.0285,
        lng: 105.8542,
      );

      expect(resolved, const LatLng(10.7790, 106.6765));
      expect(
        DriverLocationMode.demoHcm.rawGpsCoordinateSpace,
        LocationIngestCoordinateSpace.rawGps,
      );
    });

    test('device mode keeps raw GPS and bypasses the demo mapping', () {
      final resolved = DriverLocationMode.deviceGps.resolveRawGps(
        email: 'taixe@gmail.com',
        lat: 21.0285,
        lng: 105.8542,
      );

      expect(resolved, const LatLng(21.0285, 105.8542));
      expect(
        DriverLocationMode.deviceGps.rawGpsCoordinateSpace,
        LocationIngestCoordinateSpace.mapCoordinates,
      );
    });
  });
}
