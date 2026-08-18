import 'package:delivery_app/features/driver/screens/navigation/models/driver_position_source.dart';
import 'package:delivery_app/features/returns/utils/return_journey_start.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const missionOrigin = LatLng(11.0308, 106.62202);

  test('incident snapshot replaces a stale approved route origin', () {
    const incidentOrigin = LatLng(10.821, 106.721);

    final origin = resolveReturnMissionOrigin(
      approvedOrigin: missionOrigin,
      incidentOrigin: incidentOrigin,
    );

    expect(origin, incidentOrigin);
  });

  test('approved return starts from the incident snapshot', () {
    const staleProfileGps = LatLng(10.77716, 106.67237);

    final start = resolveReturnJourneyStart(
      isWeb: true,
      returnStarted: false,
      missionOrigin: missionOrigin,
      currentPosition: staleProfileGps,
      previousPosition: null,
      previousSource: DriverPositionSource.serverProfile,
    );

    expect(start, missionOrigin);
  });

  test('web refresh keeps the existing simulated position', () {
    const simulated = LatLng(11.01, 106.64);

    final start = resolveReturnJourneyStart(
      isWeb: true,
      returnStarted: true,
      missionOrigin: missionOrigin,
      currentPosition: const LatLng(10.77716, 106.67237),
      previousPosition: simulated,
      previousSource: DriverPositionSource.simulation,
    );

    expect(start, simulated);
  });

  test('a real device uses live GPS for safe navigation', () {
    const deviceGps = LatLng(11.029, 106.623);

    final start = resolveReturnJourneyStart(
      isWeb: false,
      returnStarted: true,
      missionOrigin: missionOrigin,
      currentPosition: deviceGps,
      previousPosition: null,
      previousSource: DriverPositionSource.targetFallback,
    );

    expect(start, deviceGps);
  });
}
