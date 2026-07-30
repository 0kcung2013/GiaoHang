import 'package:customer_app/core/services/osrm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('OsrmNavigationStep', () {
    test('builds a Vietnamese right-turn instruction with road name', () {
      const step = OsrmNavigationStep(
        location: LatLng(10.77, 106.7),
        distanceMeters: 180,
        durationSeconds: 25,
        maneuverType: 'turn',
        modifier: 'right',
        roadName: 'Lê Lợi',
      );

      expect(step.instruction, 'Rẽ phải vào Lê Lợi');
    });

    test('uses a clear destination instruction for arrival', () {
      const step = OsrmNavigationStep(
        location: LatLng(10.77, 106.7),
        distanceMeters: 0,
        durationSeconds: 0,
        maneuverType: 'arrive',
        modifier: 'straight',
        roadName: '',
      );

      expect(step.instruction, 'Bạn sắp đến điểm đích');
    });
  });
}
