import '../../../../../core/location/driver_location_producer_policy.dart';
import 'package:latlong2/latlong.dart';

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
}

class DriverArrivalPolicy {
  const DriverArrivalPolicy._();

  static const double arrivalRadiusMeters = 100;

  static LatLng? resolveArrival({
    required String status,
    required LatLng current,
    required LatLng target,
    required DriverPositionSource source,
  }) {
    final isActiveLeg = status == 'picking_up' || status == 'delivering';
    if (!isActiveLeg || !source.canConfirmArrival) return null;

    final meters = const Distance().as(LengthUnit.Meter, current, target);
    return meters <= arrivalRadiusMeters ? target : null;
  }
}
