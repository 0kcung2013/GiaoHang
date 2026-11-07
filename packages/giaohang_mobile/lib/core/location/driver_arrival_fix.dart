import 'package:latlong2/latlong.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show DriverMonitoring;
import 'driver_location_producer_policy.dart';
import 'physical_gps_policy.dart';

/// A measured/explicitly simulated fix, never a parcel's restored coordinate.
class DriverArrivalFix {
  const DriverArrivalFix({
    required this.position,
    required this.capturedAt,
    required this.accuracy,
    required this.mode,
    this.trafficDemoKey,
    this.simulated = false,
  });
  final LatLng position;
  final DateTime capturedAt;
  final double accuracy;
  final DriverLocationMode mode;
  final String? trafficDemoKey;
  final bool simulated;

  static DriverArrivalFix? fromMonitoring(
    DriverMonitoring? state, {
    required String driverId,
    required DriverLocationMode mode,
    String? trafficDemoKey,
  }) {
    if (state == null ||
        state.driverId != driverId ||
        state.isReclaimed ||
        state.lastCapturedAt == null ||
        state.lastLat == null ||
        state.lastLng == null ||
        state.lastAccuracy == null) {
      return null;
    }
    return DriverArrivalFix(
      position: LatLng(state.lastLat!, state.lastLng!),
      capturedAt: state.lastCapturedAt!,
      accuracy: state.lastAccuracy!,
      mode: mode,
      trafficDemoKey: trafficDemoKey,
    );
  }

  DriverArrivalFix? sampleStationarySimulation({
    required LatLng current,
    required DriverLocationMode currentMode,
    required DateTime now,
  }) {
    if (!simulated ||
        mode != currentMode ||
        current.latitude != position.latitude ||
        current.longitude != position.longitude) {
      return null;
    }
    return DriverArrivalFix(
      position: current,
      capturedAt: now,
      accuracy: 0,
      mode: mode,
      trafficDemoKey: trafficDemoKey,
      simulated: true,
    );
  }

  bool canRestore({
    required DateTime now,
    required DriverLocationMode currentMode,
    String? currentTrafficDemoKey,
  }) =>
      mode == currentMode &&
      trafficDemoKey == currentTrafficDemoKey &&
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      position.latitude >= -90 &&
      position.latitude <= 90 &&
      position.longitude >= -180 &&
      position.longitude <= 180 &&
      PhysicalGpsPolicy.accepts(
        now: now,
        capturedAt: capturedAt,
        accuracy: accuracy,
      );
}
