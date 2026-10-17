import 'package:giaohang_mobile/features/driver/screens/navigation/models/driver_position_source.dart';
import 'package:giaohang_mobile/features/returns/utils/return_journey_start.dart';
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
      usesRouteSimulation: true,
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
      usesRouteSimulation: true,
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
      usesRouteSimulation: false,
      returnStarted: true,
      missionOrigin: missionOrigin,
      currentPosition: deviceGps,
      previousPosition: null,
      previousSource: DriverPositionSource.targetFallback,
    );

    expect(start, deviceGps);
  });

  test('restored simulation stays at handoff despite an older profile', () {
    const handoff = LatLng(11.01, 106.64);
    expect(
      resolveReturnJourneyStart(
        usesRouteSimulation: true,
        returnStarted: true,
        missionOrigin: missionOrigin,
        currentPosition: missionOrigin,
        previousPosition: handoff,
        previousSource: DriverPositionSource.restoredSession,
      ),
      handoff,
    );
  });

  test('fresh device GPS takes priority over a saved return position', () {
    const freshGps = LatLng(11.02, 106.63);
    expect(
      resolveReturnJourneyStart(
        usesRouteSimulation: false,
        returnStarted: true,
        missionOrigin: missionOrigin,
        currentPosition: freshGps,
        previousPosition: const LatLng(11.01, 106.64),
        previousSource: DriverPositionSource.restoredSession,
      ),
      freshGps,
    );
  });
}
