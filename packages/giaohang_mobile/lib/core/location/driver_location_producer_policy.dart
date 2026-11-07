import 'package:latlong2/latlong.dart';

import '../utils/geo_utils.dart';

enum LocationIngestCoordinateSpace { rawGps, mapCoordinates, currentDemoGps }

extension LocationIngestCoordinateSpaceRules on LocationIngestCoordinateSpace {
  bool get shouldApplyDemoOffset =>
      this != LocationIngestCoordinateSpace.mapCoordinates;

  LatLng resolveCoordinates({
    required String? email,
    required double lat,
    required double lng,
  }) => switch (this) {
    LocationIngestCoordinateSpace.rawGps => GeoUtils.applyTestDriverOffset(
      email: email,
      lat: lat,
      lng: lng,
    ),
    LocationIngestCoordinateSpace.currentDemoGps =>
      GeoUtils.applyCurrentPositionDriverOffset(
        email: email,
        lat: lat,
        lng: lng,
      ),
    LocationIngestCoordinateSpace.mapCoordinates => LatLng(lat, lng),
  };
}

enum DriverLocationMode {
  demoHcm,
  deviceGps,
  demoCurrentPosition;

  static DriverLocationMode get defaultMode =>
      GeoUtils.enableTestDriverOffsets ? demoCurrentPosition : deviceGps;
}

extension DriverLocationModeRules on DriverLocationMode {
  LocationIngestCoordinateSpace get rawGpsCoordinateSpace => switch (this) {
    DriverLocationMode.demoHcm => LocationIngestCoordinateSpace.rawGps,
    DriverLocationMode.demoCurrentPosition =>
      LocationIngestCoordinateSpace.currentDemoGps,
    DriverLocationMode.deviceGps =>
      LocationIngestCoordinateSpace.mapCoordinates,
  };

  LatLng resolveRawGps({
    required String? email,
    required double lat,
    required double lng,
  }) => rawGpsCoordinateSpace.resolveCoordinates(
    email: email,
    lat: lat,
    lng: lng,
  );
}

class DriverLocationProducerPolicy {
  const DriverLocationProducerPolicy._();

  static bool canPublishBackgroundGps(String? activeNavigationOrderId) {
    return activeNavigationOrderId == null ||
        activeNavigationOrderId.trim().isEmpty;
  }
}
