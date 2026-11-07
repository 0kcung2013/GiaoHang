import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/location/driver_location_mode_store.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'disabled demo build defaults to real GPS and applies no demo offset',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(driverLocationModeProvider), DriverLocationMode.deviceGps);
      expect(
        await DriverLocationModeStore().load(),
        DriverLocationMode.deviceGps,
      );
      for (final email in [
        'taixe@gmail.com',
        'taixe2@gmail.com',
        'taixe3@gmail.com',
      ]) {
        for (final mode in DriverLocationMode.values) {
          expect(
            mode.resolveRawGps(email: email, lat: 10.89, lng: 106.7),
            const LatLng(10.89, 106.7),
          );
        }
      }
    },
    skip: const bool.fromEnvironment(
      'ENABLE_TEST_DRIVER_OFFSETS',
      defaultValue: true,
    ),
  );
}
