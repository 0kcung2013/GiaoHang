import 'package:delivery_app/core/location/driver_location_mode_store.dart';
import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to device GPS when no mode was selected', () async {
    final store = DriverLocationModeStore();

    expect(await store.load(), DriverLocationMode.deviceGps);
  });

  test('restores the selected Utraffic demo mode', () async {
    final store = DriverLocationModeStore();

    await store.save(DriverLocationMode.demoHcm);

    expect(await store.load(), DriverLocationMode.demoHcm);
  });
}
