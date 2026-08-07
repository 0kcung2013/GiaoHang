import 'package:delivery_app/core/utils/delivery_eta_calculator.dart';
import 'package:delivery_app/features/customer/screens/create_order/models/traffic_demo_scenario.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/traffic_demo_route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('central corridor demo route is inside the UTraffic ETA coverage', () {
    const scenario = TrafficDemoScenario.hcmHistoricCongestion;

    final eta = DeliveryEtaCalculator.calculate(
      distanceMeters: 8178,
      routeDurationSeconds: 629,
      pickupLat: scenario.pickup.latitude,
      pickupLng: scenario.pickup.longitude,
      deliveryLat: scenario.delivery.latitude,
      deliveryLng: scenario.delivery.longitude,
      quotedAt: DateTime(2026, 8, 7, 2, 50),
    );

    expect(eta.usedAiCorrection, isTrue);
    expect(eta.aiModelVersion, 'hcm_utraffic_lgbm_v2_road_profile');
    expect(eta.aiTrafficMultiplier, greaterThan(1.2));
  });

  test(
    'central clear demo route is a clearly lower-traffic AI comparison route',
    () {
      const clearScenario = TrafficDemoScenario.hcmHistoricClearTraffic;
      const congestionScenario = TrafficDemoScenario.hcmHistoricCongestion;
      final quoteTime = DateTime(2026, 8, 7, 2, 50);

      final clearEta = DeliveryEtaCalculator.calculate(
        distanceMeters: 9175,
        routeDurationSeconds: 784,
        pickupLat: clearScenario.pickup.latitude,
        pickupLng: clearScenario.pickup.longitude,
        deliveryLat: clearScenario.delivery.latitude,
        deliveryLng: clearScenario.delivery.longitude,
        quotedAt: quoteTime,
      );
      final congestionEta = DeliveryEtaCalculator.calculate(
        distanceMeters: 8178,
        routeDurationSeconds: 629,
        pickupLat: congestionScenario.pickup.latitude,
        pickupLng: congestionScenario.pickup.longitude,
        deliveryLat: congestionScenario.delivery.latitude,
        deliveryLng: congestionScenario.delivery.longitude,
        quotedAt: quoteTime,
      );

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

    expect(find.text('Ùn tắc'), findsOneWidget);
    expect(find.text('Thông thoáng'), findsOneWidget);

    final clearRouteButton = find.byKey(
      const ValueKey('traffic-demo-route-hcm_central_historic_clear_traffic'),
    );
    await tester.ensureVisible(clearRouteButton);
    await tester.tap(clearRouteButton);
    expect(selectedScenarioId, TrafficDemoScenario.hcmHistoricClearTraffic.id);
    expect(tester.takeException(), isNull);
  });
}
