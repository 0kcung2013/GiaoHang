import 'dart:async';

import 'package:giaohang_mobile/features/driver/screens/navigation/utils/driver_demo_movement_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets(
    'AI speed changes distance and Stop/Start resumes the saved position',
    (tester) async {
      final tracker = DriverDemoMovementTracker();
      const start = LatLng(10, 106);
      const route = [start, LatLng(10.01, 106)];
      var current = start;
      var index = 1;
      var speed = 30.0;
      var running = true;
      var updates = 0;
      void begin() => tracker.start(
        route: route,
        currentPosition: current,
        nextRouteIndex: index,
        canMove: () => running,
        speedKmhAt: (_) => speed,
        onPosition: (position, next, _) {
          current = position;
          index = next;
          updates++;
        },
      );
      begin();
      await tester.pump(const Duration(seconds: 12));
      expect(
        const Distance().as(LengthUnit.Meter, start, current),
        closeTo(100, 0.1),
      );
      running = false;
      tracker.stop();
      final paused = current;
      final pausedUpdates = updates;
      await tester.pump(const Duration(minutes: 1));
      expect(current, paused);
      expect(updates, pausedUpdates);
      speed = 50;
      running = true;
      begin();
      await tester.pump(const Duration(seconds: 12));
      expect(
        const Distance().as(LengthUnit.Meter, paused, current),
        closeTo(500 / 3, 1), // Distance.as làm tròn đến mét.
      );
      tracker.dispose();
    },
  );

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
