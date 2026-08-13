import 'package:latlong2/latlong.dart';

import '../../../../../core/location/driver_location_producer_policy.dart';

enum DriverPositionSource {
  deviceGps,
  browserGps,
  serverProfile,
  simulation,
  restoredSession,
  targetFallback,
}

extension DriverPositionSourceRules on DriverPositionSource {
  bool get canConfirmArrival =>
      this == DriverPositionSource.deviceGps ||
      this == DriverPositionSource.browserGps ||
      this == DriverPositionSource.simulation;

  LocationIngestCoordinateSpace get ingestCoordinateSpace => switch (this) {
    DriverPositionSource.deviceGps ||
    DriverPositionSource.browserGps => LocationIngestCoordinateSpace.rawGps,
    DriverPositionSource.serverProfile ||
    DriverPositionSource.simulation ||
    DriverPositionSource.restoredSession ||
    DriverPositionSource.targetFallback =>
      LocationIngestCoordinateSpace.mapCoordinates,
  };

  LatLng resolveForPublishing({
    required DriverLocationMode locationMode,
    required String? email,
    required LatLng position,
  }) {
    if (!ingestCoordinateSpace.shouldApplyDemoOffset) return position;
    return locationMode.resolveRawGps(
      email: email,
      lat: position.latitude,
      lng: position.longitude,
    );
  }
}
