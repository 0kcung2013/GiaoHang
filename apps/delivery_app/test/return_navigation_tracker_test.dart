import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:delivery_app/features/returns/utils/return_navigation_tracker.dart';

void main() {
  group('ReturnNavigationTracker', () {
    testWidgets('tiếp tục từ vị trí giữa đoạn đường, không lùi về đỉnh', (
      tester,
    ) async {
      final tracker = ReturnNavigationTracker(
        simulationInterval: const Duration(seconds: 1),
      );
      final route = const [
        LatLng(10.7800, 106.6800),
        LatLng(10.7810, 106.6810),
        LatLng(10.7820, 106.6820),
        LatLng(10.7830, 106.6830),
      ];
      final positions = <LatLng>[];
      var canMove = true;

      tracker.startSimulation(
        route: route,
        currentPosition: const LatLng(10.7811, 106.6811),
        canMove: () => canMove,
        onPosition: (position) {
          positions.add(position);
          canMove = false;
        },
      );
      await tester.pump(const Duration(seconds: 1));

      expect(positions, hasLength(1));
      expect(positions.single.latitude, greaterThan(10.7811));
      expect(
        const Distance(roundResult: false).as(
          LengthUnit.Meter,
          const LatLng(10.7811, 106.6811),
          positions.single,
        ),
        closeTo(15, 0.1),
      );
      await tracker.dispose();
    });

    test('dừng ngay khi chuyến hoàn không còn cho phép di chuyển', () async {
      final tracker = ReturnNavigationTracker(
        simulationInterval: const Duration(milliseconds: 2),
      );
      final positions = <LatLng>[];

      tracker.startSimulation(
        route: const [LatLng(10, 106), LatLng(10.001, 106.001)],
        currentPosition: null,
        canMove: () => false,
        onPosition: positions.add,
      );
      await Future<void>.delayed(const Duration(milliseconds: 8));

      expect(positions, isEmpty);
      expect(tracker.isSimulating, isFalse);
      await tracker.dispose();
    });
  });
}
