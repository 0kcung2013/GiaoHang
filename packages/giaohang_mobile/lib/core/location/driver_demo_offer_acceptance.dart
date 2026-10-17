import 'package:latlong2/latlong.dart';

import '../models/traffic_demo_clock.dart';
import '../utils/geo_utils.dart';
import 'driver_location_producer_policy.dart';

const _syncError =
    'Chưa xác nhận được vị trí demo. Vui lòng thử lại trước khi nhận đơn.';

/// Ranh giới nhận đơn: vị trí UI và vị trí backend tính ETA phải đồng nhất.
Future<void> acceptAfterDemoLocationSync({
  required DriverLocationMode mode,
  required String? email,
  required String? trafficDemoKey,
  required Future<void> Function(LatLng position) publish,
  required Future<LatLng?> Function() readLatest,
  required Future<void> Function() accept,
}) async {
  if (mode == DriverLocationMode.demoHcm &&
      TrafficDemoClock.forecastAt(trafficDemoKey) != null &&
      GeoUtils.hasTestDriverOffset(email)) {
    final expected = GeoUtils.applyTestDriverOffset(
      email: email,
      lat: 0,
      lng: 0,
    );
    await publish(expected);
    final actual = await readLatest();
    if (actual == null ||
        !actual.latitude.isFinite ||
        !actual.longitude.isFinite ||
        const Distance().as(LengthUnit.Meter, actual, expected) > 0.5) {
      throw Exception(_syncError);
    }
  }
  await accept();
}
