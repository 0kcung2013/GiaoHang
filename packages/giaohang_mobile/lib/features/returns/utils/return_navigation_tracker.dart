import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/delivery_map_utils.dart';
import '../../driver/screens/navigation/utils/driver_navigation_motion.dart';

/// Quản lý nguồn chuyển động của chuyến hoàn: GPS thật trên thiết bị và
/// mô phỏng theo polyline trên Web/demo.
class ReturnNavigationTracker {
  ReturnNavigationTracker({
    this.simulationInterval = const Duration(seconds: 1),
    this.simulationSpeedMetersPerSecond = 15,
  }) : assert(simulationInterval > Duration.zero),
       assert(simulationSpeedMetersPerSecond > 0);

  final Duration simulationInterval;
  final double simulationSpeedMetersPerSecond;
  static const double routeEndDistanceMeters = 1;

  Timer? _simulationTimer;
  StreamSubscription<Position>? _positionStream;
  int _routeIndex = 0;

  bool get isSimulating => _simulationTimer?.isActive ?? false;

  void startSimulation({
    required List<LatLng> route,
    required LatLng? currentPosition,
    required bool Function() canMove,
    required FutureOr<void> Function(LatLng position) onPosition,
  }) {
    stopSimulation();
    if (route.length < 2 || !canMove()) return;

    // Tiếp tục từ điểm trên đoạn đường, không lùi về đỉnh OSRM gần nhất.
    var position = DeliveryMapUtils.snapToRoute(
      fullRoute: route,
      current: currentPosition ?? route.first,
    );
    final remaining = DeliveryMapUtils.remainingRoute(
      fullRoute: route,
      current: position,
    );
    _routeIndex = 1;

    _simulationTimer = Timer.periodic(simulationInterval, (timer) {
      if (!canMove() || _routeIndex >= remaining.length) {
        timer.cancel();
        return;
      }
      final step = DriverNavigationMotion.advanceAlongRoute(
        route: remaining,
        current: position,
        nextRouteIndex: _routeIndex,
        maxDistanceMeters:
            simulationSpeedMetersPerSecond *
            simulationInterval.inMicroseconds /
            Duration.microsecondsPerSecond,
      );
      position = step.position;
      _routeIndex = step.nextRouteIndex;
      unawaited(Future<void>.sync(() => onPosition(position)));
      if (step.reachedEnd) timer.cancel();
    });
  }

  void startGpsStream({
    required FutureOr<void> Function(LatLng position) onPosition,
    void Function(Object error)? onError,
  }) {
    unawaited(_positionStream?.cancel());
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 5,
          ),
        ).listen(
          (position) =>
              onPosition(LatLng(position.latitude, position.longitude)),
          onError: onError,
        );
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  Future<void> stop() async {
    stopSimulation();
    await _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> dispose() async {
    await stop();
  }

  static int nearestRouteIndex(List<LatLng> route, LatLng position) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    const distance = Distance();

    for (var index = 0; index < route.length; index++) {
      final meters = distance.as(LengthUnit.Meter, position, route[index]);
      if (meters < nearestDistance) {
        nearestDistance = meters;
        nearestIndex = index;
      }
    }
    return nearestIndex;
  }
}
