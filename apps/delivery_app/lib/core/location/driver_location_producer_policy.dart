import 'package:latlong2/latlong.dart';

import '../utils/geo_utils.dart';

enum LocationIngestCoordinateSpace { rawGps, mapCoordinates }

extension LocationIngestCoordinateSpaceRules on LocationIngestCoordinateSpace {
  bool get shouldApplyDemoOffset =>
      this == LocationIngestCoordinateSpace.rawGps;
}

enum DriverLocationMode { demoHcm, deviceGps }

extension DriverLocationModeRules on DriverLocationMode {
  LocationIngestCoordinateSpace get rawGpsCoordinateSpace => switch (this) {
    DriverLocationMode.demoHcm => LocationIngestCoordinateSpace.rawGps,
    DriverLocationMode.deviceGps =>
      LocationIngestCoordinateSpace.mapCoordinates,
  };

  LatLng resolveRawGps({
    required String? email,
    required double lat,
    required double lng,
  }) => switch (this) {
    DriverLocationMode.demoHcm => GeoUtils.applyTestDriverOffset(
      email: email,
      lat: lat,
      lng: lng,
    ),
    DriverLocationMode.deviceGps => LatLng(lat, lng),
  };
}

class DriverLocationProducerPolicy {
  const DriverLocationProducerPolicy._();

  static bool canPublishBackgroundGps(String? activeNavigationOrderId) {
    return activeNavigationOrderId == null ||
        activeNavigationOrderId.trim().isEmpty;
  }
}
