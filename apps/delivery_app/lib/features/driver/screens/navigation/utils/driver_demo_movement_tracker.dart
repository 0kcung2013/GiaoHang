import 'dart:async';

import 'package:latlong2/latlong.dart';

import 'driver_navigation_motion.dart';

/// Tiếp tục mô phỏng vị trí cho đơn active khi navigation map không còn mount.
class DriverDemoMovementTracker {
  DriverDemoMovementTracker({
    this.interval = const Duration(milliseconds: 250),
    this.speedMetersPerSecond = 15,
  });

  final Duration interval;
  final double speedMetersPerSecond;
  Timer? _timer;

  bool get isRunning => _timer?.isActive ?? false;

  void start({
    required List<LatLng> route,
    required LatLng currentPosition,
    required int nextRouteIndex,
    required bool Function() canMove,
    required void Function(LatLng position, int nextIndex, bool reachedEnd)
    onPosition,
  }) {
    stop();
    if (route.length < 2 || !canMove()) return;

    var current = currentPosition;
    var index = nextRouteIndex.clamp(1, route.length);
    _timer = Timer.periodic(interval, (timer) {
      if (!canMove()) {
        timer.cancel();
        return;
      }
      final step = DriverNavigationMotion.advanceAlongRoute(
        route: route,
        current: current,
        nextRouteIndex: index,
        maxDistanceMeters:
            speedMetersPerSecond *
            interval.inMilliseconds /
            Duration.millisecondsPerSecond,
      );
      current = step.position;
      index = step.nextRouteIndex;
      onPosition(current, index, step.reachedEnd);
      if (step.reachedEnd) timer.cancel();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}
