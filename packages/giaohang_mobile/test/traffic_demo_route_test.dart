import 'dart:convert';
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'dart:io';

import 'package:giaohang_mobile/core/utils/delivery_eta_calculator.dart';
import 'package:giaohang_mobile/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:giaohang_mobile/core/utils/geo_utils.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/models/traffic_demo_scenario.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/traffic_demo_time_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/utraffic_demo.json').readAsStringSync(),
  );
  DeliveryEtaEstimate estimate(String id, TrafficDemoScenario scenario) {
    final route = fixture[id];
    return DeliveryEtaCalculator.calculate(
      distanceMeters: (route['distance'] as num).toDouble(),
      routeDurationSeconds: (route['duration'] as num).toDouble(),
      pickupLat: scenario.pickup.latitude,
      pickupLng: scenario.pickup.longitude,
      deliveryLat: scenario.delivery.latitude,
      deliveryLng: scenario.delivery.longitude,
      routePoints: (route['points'] as List)
          .map(
            (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          )
          .toList(),
      quotedAt: scenario.forecastAt,
      speedProfile: DeliveryEtaRouteProfile.fromJson(route['profile']),
    );
  }

  test('demo uses public place pins with a separate road approach', () {
    final evidence = jsonDecode(
      File('test/fixtures/traffic_demo_locations.json').readAsStringSync(),
    );
    final locations = evidence['locations'];
    LatLng pin(String name) {
      final point = locations[name]['point'];
      return LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble());
    }

    for (final scenario in [
      TrafficDemoScenario.hcmHistoricCongestion,
      TrafficDemoScenario.hcmHistoricClearTraffic,
    ]) {
      expect(scenario.pickup, pin('pickup'));
      expect(scenario.delivery, pin('delivery'));
      expect(scenario.pickupAddress, locations['pickup']['address']);
      expect(scenario.deliveryAddress, locations['delivery']['address']);
    }
    expect(GeoUtils.testDriverDemoPositions['taixe@gmail.com'], pin('driver'));
    for (final waypoint in [
      ...evidence['delivery_waypoints'],
      ...evidence['approach_waypoints'],
    ]) {
      expect(waypoint['distance'], inExclusiveRange(3, 25));
    }
    final dispatch = jsonDecode(
      File('test/fixtures/traffic_demo_dispatch.json').readAsStringSync(),
    );
    expect(dispatch['table']['distances'][0][0], inExclusiveRange(100, 2000));
  });

  test('central corridor demo route is inside the UTraffic ETA coverage', () {
    const scenario = TrafficDemoScenario.hcmHistoricCongestion;

    final eta = estimate('congested', scenario);

    expect(eta.usedAiCorrection, isTrue);
    expect(eta.aiModelVersion, 'hcm_utraffic_segment_speed_v1');
    expect(eta.aiTrafficMultiplier, greaterThan(0.7));
  });

  test('selectable demo has an AI prediction for every rendered section', () {
    for (final key in ['congested', 'clear']) {
      final profile = DeliveryEtaRouteProfile.fromJson(
        fixture[key]['profile'],
      )!;
      expect(profile.trafficSegments, isNotEmpty);
      expect(
        profile.trafficSegments.every(
          (segment) => segment.level != DeliveryTrafficLevel.unavailable,
        ),
        isTrue,
        reason: '$key demo must have no sections without AI prediction',
      );
    }
  });

  test(
    'central clear demo route is a clearly lower-traffic AI comparison route',
    () {
      const clearScenario = TrafficDemoScenario.hcmHistoricClearTraffic;
      const congestionScenario = TrafficDemoScenario.hcmHistoricCongestion;
      final clearEta = estimate('clear', clearScenario);
      final congestionEta = estimate('congested', congestionScenario);

      expect(clearEta.usedAiCorrection, isTrue);
      expect(clearEta.aiTrafficMultiplier, lessThan(1.2));
      expect(
        clearEta.aiTrafficMultiplier,
        lessThan(congestionEta.aiTrafficMultiplier! - 0.15),
      );
      expect(
        congestionEta.minMinutes,
        greaterThanOrEqualTo(clearEta.minMinutes + 1),
      );
      expect(
        congestionEta.maxMinutes,
        greaterThanOrEqualTo(clearEta.maxMinutes + 1),
      );
    },
  );

  testWidgets('demo route card is readable and applies the selected route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? selectedScenarioId;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TrafficDemoTimeButton(
                      scenario: TrafficDemoScenario.hcmHistoricCongestion,
                      isApplied: false,
                      onApply: () => selectedScenarioId =
                          TrafficDemoScenario.hcmHistoricCongestion.id,
                    ),
                    const SizedBox(height: 8),
                    TrafficDemoTimeButton(
                      scenario: TrafficDemoScenario.hcmHistoricClearTraffic,
                      isApplied: false,
                      onApply: () => selectedScenarioId =
                          TrafficDemoScenario.hcmHistoricClearTraffic.id,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Cao điểm · 18:00'), findsOneWidget);
    expect(find.text('Ngoài cao điểm · 12:00'), findsOneWidget);

    final clearRouteButton = find.byKey(
      const ValueKey('traffic-demo-route-hcm_central_historic_clear_traffic'),
    );
    await tester.ensureVisible(clearRouteButton);
    await tester.tap(clearRouteButton);
    expect(selectedScenarioId, TrafficDemoScenario.hcmHistoricClearTraffic.id);
    expect(tester.takeException(), isNull);
  });
}
