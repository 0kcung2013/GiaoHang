import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:delivery_app/features/returns/utils/return_navigation_tracker.dart';

void main() {
  group('ReturnNavigationTracker', () {
    test('tiếp tục mô phỏng từ điểm gần vị trí hiện tại nhất', () async {
      final tracker = ReturnNavigationTracker(
        simulationInterval: const Duration(milliseconds: 2),
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
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(positions, [route[1]]);
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
