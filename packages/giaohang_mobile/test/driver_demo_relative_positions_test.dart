import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/location/driver_location_mode_store.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'default demo uses current GPS as driver 1 anchor and separates driver 2 and 3',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(
        c.read(driverLocationModeProvider),
        DriverLocationMode.demoCurrentPosition,
      );
      expect(
        await DriverLocationModeStore().load(),
        DriverLocationMode.demoCurrentPosition,
      );
      const base = LatLng(10.891083, 106.701671);
      LatLng position(String email) => DriverLocationMode.demoCurrentPosition
          .resolveRawGps(email: email, lat: base.latitude, lng: base.longitude);
      final first = position('taixe@gmail.com');
      final second = position('taixe2@gmail.com');
      final third = position('taixe3@gmail.com');
      expect(first, base);
      expect(const Distance()(first, second), inInclusiveRange(140, 180));
      expect(const Distance()(first, third), inInclusiveRange(300, 340));
      expect(const Distance()(second, third), greaterThan(100));
    },
  );

  test(
    'moving the current anchor moves the entire demo group; HCM group stays fixed',
    () {
      for (final email in [
        'taixe@gmail.com',
        'taixe2@gmail.com',
        'taixe3@gmail.com',
      ]) {
        final currentA = DriverLocationMode.demoCurrentPosition.resolveRawGps(
          email: email,
          lat: 10.89,
          lng: 106.7,
        );
        final currentB = DriverLocationMode.demoCurrentPosition.resolveRawGps(
          email: email,
          lat: 10.9,
          lng: 106.71,
        );
        expect(currentB.latitude - currentA.latitude, closeTo(0.01, 1e-9));
        expect(currentB.longitude - currentA.longitude, closeTo(0.01, 1e-9));
        final hcmA = DriverLocationMode.demoHcm.resolveRawGps(
          email: email,
          lat: 10.89,
          lng: 106.7,
        );
        final hcmB = DriverLocationMode.demoHcm.resolveRawGps(
          email: email,
          lat: 21,
          lng: 105,
        );
        expect(hcmA, hcmB);
      }
    },
  );

  test('explicit real GPS and unknown accounts receive no relative offset', () {
    for (final email in [
      'taixe@gmail.com',
      'taixe2@gmail.com',
      'taixe3@gmail.com',
    ]) {
      expect(
        DriverLocationMode.deviceGps.resolveRawGps(
          email: email,
          lat: 10.89,
          lng: 106.7,
        ),
        const LatLng(10.89, 106.7),
      );
    }
    expect(
      DriverLocationMode.demoCurrentPosition.resolveRawGps(
        email: 'other@example.com',
        lat: 10.89,
        lng: 106.7,
      ),
      const LatLng(10.89, 106.7),
    );
  });
}
