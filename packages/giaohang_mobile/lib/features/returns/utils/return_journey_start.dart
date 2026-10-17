import 'package:latlong2/latlong.dart';

import '../../driver/screens/navigation/models/driver_position_source.dart';

LatLng resolveReturnMissionOrigin({
  required LatLng approvedOrigin,
  required LatLng? incidentOrigin,
}) => incidentOrigin ?? approvedOrigin;

bool shouldKeepReturnJourneyPosition({
  required bool usesRouteSimulation,
  required LatLng? previousPosition,
  required DriverPositionSource previousSource,
}) =>
    usesRouteSimulation &&
    previousPosition != null &&
    (previousSource == DriverPositionSource.simulation ||
        previousSource == DriverPositionSource.restoredSession);

LatLng resolveReturnJourneyStart({
  required bool usesRouteSimulation,
  required bool returnStarted,
  required LatLng missionOrigin,
  required LatLng? currentPosition,
  required LatLng? previousPosition,
  required DriverPositionSource previousSource,
}) {
  if (!returnStarted) return missionOrigin;
  if (shouldKeepReturnJourneyPosition(
    usesRouteSimulation: usesRouteSimulation,
    previousPosition: previousPosition,
    previousSource: previousSource,
  )) {
    return previousPosition!;
  }
  return currentPosition ?? previousPosition ?? missionOrigin;
}
