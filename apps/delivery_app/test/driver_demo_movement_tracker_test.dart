import 'dart:async';

import 'package:delivery_app/features/driver/screens/navigation/utils/driver_demo_movement_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'keeps emitting demo positions after its map owner has been removed',
    () async {
      final tracker = DriverDemoMovementTracker(
        interval: const Duration(milliseconds: 1),
        speedMetersPerSecond: 100,
      );
      addTearDown(tracker.dispose);
      final positions = <LatLng>[];
      final enoughUpdates = Completer<void>();

      tracker.start(
        route: const [LatLng(10, 106), LatLng(10.01, 106)],
        currentPosition: const LatLng(10, 106),
        nextRouteIndex: 1,
        canMove: () => true,
        onPosition: (position, _, _) {
          positions.add(position);
          if (positions.length == 3 && !enoughUpdates.isCompleted) {
            enoughUpdates.complete();
          }
        },
      );

      await enoughUpdates.future.timeout(const Duration(seconds: 1));

      expect(positions, hasLength(greaterThanOrEqualTo(3)));
      expect(positions.last.latitude, greaterThan(positions.first.latitude));
    },
  );
}
