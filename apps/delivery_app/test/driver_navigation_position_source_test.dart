import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_position_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const raw = LatLng(21.0285, 105.8542);

  test('device GPS uses fixed TP.HCM point in demo mode', () {
    expect(
      DriverPositionSource.deviceGps.resolveForPublishing(
        locationMode: DriverLocationMode.demoHcm,
        email: 'taixe@gmail.com',
        position: raw,
      ),
      const LatLng(10.7790, 106.6765),
    );
  });

  test('device GPS stays real when current-position mode is selected', () {
    expect(
      DriverPositionSource.deviceGps.resolveForPublishing(
        locationMode: DriverLocationMode.deviceGps,
        email: 'taixe@gmail.com',
        position: raw,
      ),
      raw,
    );
  });

  test('simulation coordinates are never offset again', () {
    expect(
      DriverPositionSource.simulation.resolveForPublishing(
        locationMode: DriverLocationMode.demoHcm,
        email: 'taixe@gmail.com',
        position: raw,
      ),
      raw,
    );
  });
}
