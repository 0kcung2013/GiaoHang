import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/utils/geo_utils.dart';
import 'package:delivery_app/features/driver/screens/home/utils/driver_dashboard_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('uses the fixed TP.HCM demo GPS before calculating order distance', () {
    final position = resolveDriverDashboardPosition(
      locationMode: DriverLocationMode.demoHcm,
      email: 'taixe@gmail.com',
      rawLat: 21.0285,
      rawLng: 105.8542,
      storedLat: 21.0285,
      storedLng: 105.8542,
    );

    expect(position, const LatLng(10.7790, 106.6765));
  });

  test(
    'keeps the already adjusted stored position when device GPS is absent',
    () {
      final position = resolveDriverDashboardPosition(
        locationMode: DriverLocationMode.demoHcm,
        email: 'taixe@gmail.com',
        storedLat: 10.7790,
        storedLng: 106.6765,
      );

      expect(position, const LatLng(10.7790, 106.6765));
    },
  );

  test('uses raw device GPS when the session selects current position', () {
    final position = resolveDriverDashboardPosition(
      locationMode: DriverLocationMode.deviceGps,
      email: 'taixe@gmail.com',
      rawLat: 21.0285,
      rawLng: 105.8542,
      storedLat: 10.7790,
      storedLng: 106.6765,
    );

    expect(position, const LatLng(21.0285, 105.8542));
  });

  test('falls back to the stored position when dashboard GPS is absent', () {
    final position = resolveDriverOfferPosition(
      dashboardPosition: null,
      storedLat: 11.0308203237526,
      storedLng: 106.622019716328,
    );

    expect(position, const LatLng(11.0308203237526, 106.622019716328));
  });

  test(
    'incoming offer label prefers the fresher device GPS over stale stored GPS',
    () {
      const deviceGps = LatLng(10.7790, 106.6765);
      const staleStoredGps = LatLng(10.8500, 106.6765);
      const pickupNearDevice = LatLng(10.7791, 106.6765);

      final dashboardPosition = resolveDriverDashboardPosition(
        locationMode: DriverLocationMode.deviceGps,
        email: 'driver@example.com',
        rawLat: deviceGps.latitude,
        rawLng: deviceGps.longitude,
        storedLat: staleStoredGps.latitude,
        storedLng: staleStoredGps.longitude,
      );
      final offerPosition = resolveDriverOfferPosition(
        dashboardPosition: dashboardPosition,
        storedLat: staleStoredGps.latitude,
        storedLng: staleStoredGps.longitude,
      );

      final distanceFromDevice = GeoUtils.distanceMeters(
        fromLat: deviceGps.latitude,
        fromLng: deviceGps.longitude,
        toLat: pickupNearDevice.latitude,
        toLng: pickupNearDevice.longitude,
      );
      final distanceShownForOffer = GeoUtils.distanceMeters(
        fromLat: offerPosition!.latitude,
        fromLng: offerPosition.longitude,
        toLat: pickupNearDevice.latitude,
        toLng: pickupNearDevice.longitude,
      );

      expect(dashboardPosition, deviceGps);
      expect(offerPosition, deviceGps);
      expect(distanceFromDevice, lessThan(20));
      expect(distanceShownForOffer, closeTo(distanceFromDevice, 0.001));
    },
  );
}
