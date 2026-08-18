import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Quản lý nguồn chuyển động của chuyến hoàn: GPS thật trên thiết bị và
/// mô phỏng theo polyline trên Web/demo.
class ReturnNavigationTracker {
  ReturnNavigationTracker({
    this.simulationInterval = const Duration(seconds: 1),
  });

  final Duration simulationInterval;

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

    _routeIndex = currentPosition == null
        ? 0
        : nearestRouteIndex(route, currentPosition);

    _simulationTimer = Timer.periodic(simulationInterval, (timer) {
      if (!canMove() || _routeIndex >= route.length) {
        timer.cancel();
        return;
      }
      final next = route[_routeIndex];
      _routeIndex++;
      unawaited(Future<void>.sync(() => onPosition(next)));
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

  Future<void> dispose() async {
    stopSimulation();
    await _positionStream?.cancel();
    _positionStream = null;
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
