import 'package:delivery_app/core/services/nearest_driver_service.dart';
import 'package:delivery_app/core/utils/geo_utils.dart';
import 'package:delivery_app/features/customer/screens/create_order/models/traffic_demo_scenario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary demo driver can receive every selectable AI demo route', () {
    final primaryDriver = GeoUtils.testDriverDemoPositions['taixe@gmail.com'];
    const scenarios = [
      TrafficDemoScenario.hcmHistoricCongestion,
      TrafficDemoScenario.hcmHistoricClearTraffic,
    ];

    for (final scenario in scenarios) {
      final distance = GeoUtils.distanceMeters(
        fromLat: primaryDriver!.latitude,
        fromLng: primaryDriver.longitude,
        toLat: scenario.pickup.latitude,
        toLng: scenario.pickup.longitude,
      );

      expect(
        distance,
        lessThanOrEqualTo(NearestDriverService.radiusMeters),
        reason: '${scenario.title} must be offered to the primary demo driver',
      );
    }
  });
}
