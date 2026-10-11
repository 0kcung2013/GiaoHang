import 'dart:convert';
import 'dart:io';

import 'package:delivery_app/core/utils/delivery_eta_calculator.dart';
import 'package:delivery_app/features/customer/screens/create_order/models/traffic_demo_scenario.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/traffic_demo_route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/traffic_demo_osrm_routes.json').readAsStringSync(),
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
    );
  }

  test('central corridor demo route is inside the UTraffic ETA coverage', () {
    const scenario = TrafficDemoScenario.hcmHistoricCongestion;

    final eta = estimate('congested', scenario);

    expect(eta.usedAiCorrection, isTrue);
    expect(eta.aiModelVersion, 'smarttraffic_hcm_speed_v1');
    expect(eta.aiTrafficMultiplier, greaterThan(0.7));
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
        greaterThanOrEqualTo(clearEta.minMinutes + 2),
      );
      expect(
        congestionEta.maxMinutes,
        greaterThanOrEqualTo(clearEta.maxMinutes + 2),
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
                    TrafficDemoRouteCard(
                      scenario: TrafficDemoScenario.hcmHistoricCongestion,
                      isApplied: false,
                      onApply: () => selectedScenarioId =
                          TrafficDemoScenario.hcmHistoricCongestion.id,
                    ),
                    const SizedBox(height: 8),
                    TrafficDemoRouteCard(
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

    expect(find.text('Cao điểm · 07:00'), findsOneWidget);
    expect(find.text('Ngoài cao điểm · 14:00'), findsOneWidget);

    final clearRouteButton = find.byKey(
      const ValueKey('traffic-demo-route-hcm_central_historic_clear_traffic'),
    );
    await tester.ensureVisible(clearRouteButton);
    await tester.tap(clearRouteButton);
    expect(selectedScenarioId, TrafficDemoScenario.hcmHistoricClearTraffic.id);
    expect(tester.takeException(), isNull);
  });
}
