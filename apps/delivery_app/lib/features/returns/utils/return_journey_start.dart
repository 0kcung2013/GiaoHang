import 'package:latlong2/latlong.dart';

import '../../driver/screens/navigation/models/driver_position_source.dart';

LatLng resolveReturnMissionOrigin({
  required LatLng approvedOrigin,
  required LatLng? incidentOrigin,
}) => incidentOrigin ?? approvedOrigin;

LatLng resolveReturnJourneyStart({
  required bool isWeb,
  required bool returnStarted,
  required LatLng missionOrigin,
  required LatLng? currentPosition,
  required LatLng? previousPosition,
  required DriverPositionSource previousSource,
}) {
  if (!returnStarted) return missionOrigin;
  if (!isWeb) {
    return currentPosition ?? previousPosition ?? missionOrigin;
  }
  if (previousSource == DriverPositionSource.simulation &&
      previousPosition != null) {
    return previousPosition;
  }
  return currentPosition ?? previousPosition ?? missionOrigin;
}
