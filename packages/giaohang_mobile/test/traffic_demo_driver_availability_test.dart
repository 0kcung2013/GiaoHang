import 'dart:convert';
import 'dart:io';

import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/services/nearest_driver_service.dart';
import 'package:giaohang_mobile/core/utils/geo_utils.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/models/traffic_demo_scenario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final email in const [
    'taixe@gmail.com',
    'taixe2@gmail.com',
    'taixe3@gmail.com',
  ]) {
    test('$email can receive every selectable AI demo route', () {
      final driver = GeoUtils.testDriverDemoPositions[email]!;
      const scenarios = [
        TrafficDemoScenario.hcmHistoricCongestion,
        TrafficDemoScenario.hcmHistoricClearTraffic,
      ];

      for (final scenario in scenarios) {
        final distance = GeoUtils.distanceMeters(
          fromLat: driver.latitude,
          fromLng: driver.longitude,
          toLat: scenario.pickup.latitude,
          toLng: scenario.pickup.longitude,
        );

        expect(
          distance,
          lessThanOrEqualTo(NearestDriverService.radiusMeters),
          reason: '${scenario.title} must remain eligible after a transfer',
        );
      }
    });
  }

  test(
    'primary demo driver passes the production OSRM road-distance offer limit',
    () {
      final replay = jsonDecode(
        File('test/fixtures/traffic_demo_dispatch.json').readAsStringSync(),
      );
      final primary = GeoUtils.testDriverDemoPositions['taixe@gmail.com']!;
      const scenario = TrafficDemoScenario.hcmHistoricCongestion;
      expect(primary.latitude, replay['driver']['lat']);
      expect(primary.longitude, replay['driver']['lng']);
      expect(scenario.pickup.latitude, replay['pickup']['lat']);
      expect(scenario.pickup.longitude, replay['pickup']['lng']);
      expect(
        replay['table']['distances'][0][0],
        lessThanOrEqualTo(NearestDriverService.radiusMeters),
        reason: 'Offers use road distance, not direct GPS distance',
      );
      expect(replay['table']['sources'][0]['distance'], lessThanOrEqualTo(100));
      expect(
        replay['table']['destinations'][0]['distance'],
        lessThanOrEqualTo(100),
      );
      expect(replay['eligible'], isTrue);
    },
  );

  test('all demo GPS points match eligible road quotes in transfer order', () {
    final replay =
        jsonDecode(
              File(
                'test/fixtures/traffic_demo_transfer_dispatch.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final drivers = replay['drivers'] as List<dynamic>;
    final table = replay['table'] as Map<String, dynamic>;
    const scenarios = [
      TrafficDemoScenario.hcmHistoricCongestion,
      TrafficDemoScenario.hcmHistoricClearTraffic,
    ];

    expect(drivers.map((driver) => driver['email']), [
      'taixe@gmail.com',
      'taixe2@gmail.com',
      'taixe3@gmail.com',
    ]);
    expect(table['code'], 'Ok');
    expect(table['distances'], hasLength(drivers.length));
    expect(table['sources'], hasLength(drivers.length));
    expect(table['destinations'][0]['distance'], lessThanOrEqualTo(100));

    for (final scenario in scenarios) {
      expect(scenario.pickup.latitude, replay['pickup']['lat']);
      expect(scenario.pickup.longitude, replay['pickup']['lng']);
    }

    var previousMeters = 0.0;
    for (var index = 0; index < drivers.length; index++) {
      final driver = drivers[index];
      final position = DriverLocationMode.demoHcm.resolveRawGps(
        email: driver['email'] as String,
        lat: 21.0285,
        lng: 105.8542,
      );
      expect(position.latitude, driver['lat']);
      expect(position.longitude, driver['lng']);
      expect(table['sources'][index]['distance'], lessThanOrEqualTo(100));
      final meters = (table['distances'][index][0] as num).toDouble();
      expect(meters, greaterThan(previousMeters));
      expect(meters, lessThanOrEqualTo(NearestDriverService.radiusMeters));
      previousMeters = meters;
    }
  });
}
