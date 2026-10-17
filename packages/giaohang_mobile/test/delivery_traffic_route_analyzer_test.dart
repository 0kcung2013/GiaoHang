import 'package:giaohang_mobile/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:giaohang_mobile/core/widgets/delivery_traffic_map_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('DeliveryTrafficRouteAnalyzer', () {
    test('synthetic maps use exact 25, 50, 75 percent slowdown boundaries', () {
      for (final sample in [
        (1.249999, DeliveryTrafficLevel.clear),
        (1.25, DeliveryTrafficLevel.moderate),
        (1.499999, DeliveryTrafficLevel.moderate),
        (1.50, DeliveryTrafficLevel.heavy),
        (1.749999, DeliveryTrafficLevel.heavy),
        (1.75, DeliveryTrafficLevel.congested),
      ]) {
        expect(
          DeliveryTrafficRouteAnalyzer.classifyMultiplier(
            sample.$1,
            isSynthetic: true,
          ),
          sample.$2,
        );
      }
      expect(
        DeliveryTrafficRouteAnalyzer.classifyMultiplier(1.49),
        DeliveryTrafficLevel.heavy,
      );
      expect(
        DeliveryTrafficRouteAnalyzer.classifyMultiplier(1.75),
        DeliveryTrafficLevel.heavy,
      );
    });

    test('classifies historical multipliers into map levels', () {
      expect(
        DeliveryTrafficRouteAnalyzer.classifyMultiplier(null),
        DeliveryTrafficLevel.unavailable,
      );
      expect(
        DeliveryTrafficRouteAnalyzer.classifyMultiplier(1.10),
        DeliveryTrafficLevel.clear,
      );
      expect(
        DeliveryTrafficRouteAnalyzer.classifyMultiplier(1.35),
        DeliveryTrafficLevel.moderate,
      );
      expect(
        DeliveryTrafficRouteAnalyzer.classifyMultiplier(1.60),
        DeliveryTrafficLevel.heavy,
      );
      expect(
        DeliveryTrafficRouteAnalyzer.classifyMultiplier(2.00),
        DeliveryTrafficLevel.congested,
      );
    });

    test('a route without a stored forecast remains unavailable', () {
      const route = [
        LatLng(10.775, 106.680),
        LatLng(10.780, 106.685),
        LatLng(10.785, 106.690),
      ];

      final segments = DeliveryTrafficRouteAnalyzer.analyze(
        routePoints: route,
        quotedAt: DateTime(2026, 8, 7, 17, 30),
      );

      expect(segments, isNotEmpty);
      expect(segments.hasHistoricalTraffic, isFalse);
      expect(segments.hasUnavailableTraffic, isTrue);
      expect(segments.first.points.first, route.first);
      expect(segments.last.points.last, route.last);
      expect(
        segments.every((segment) => segment.maxHistoricalMultiplier == null),
        isTrue,
      );
    });

    test('keeps Bình Dương route blue because UTraffic has no coverage', () {
      const route = [
        LatLng(11.050, 106.660),
        LatLng(11.055, 106.665),
        LatLng(11.060, 106.670),
      ];

      final segments = DeliveryTrafficRouteAnalyzer.analyze(
        routePoints: route,
        quotedAt: DateTime(2026, 8, 7, 17, 30),
      );

      expect(segments, isNotEmpty);
      expect(segments.hasHistoricalTraffic, isFalse);
      expect(segments.hasUnavailableTraffic, isTrue);
      expect(
        segments.every(
          (segment) => segment.level == DeliveryTrafficLevel.unavailable,
        ),
        isTrue,
      );
    });
  });

  testWidgets('traffic legend explains colors without relying on color alone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const segments = [
      DeliveryTrafficSegment(
        points: [LatLng(10.77, 106.68), LatLng(10.78, 106.69)],
        level: DeliveryTrafficLevel.congested,
        maxHistoricalMultiplier: 1.65,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: DeliveryTrafficMapLegend(segments: segments),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Vận tốc theo tuyến'), findsOneWidget);
    expect(find.text('>40 km/h'), findsOneWidget);
    expect(find.text('34–40 km/h'), findsOneWidget);
    expect(find.text('28–34 km/h'), findsOneWidget);
    expect(find.text('<28 km/h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
