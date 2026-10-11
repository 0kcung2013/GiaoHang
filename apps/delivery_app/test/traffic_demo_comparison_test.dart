import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:delivery_app/core/ml/delivery_eta_ai_calibrator.dart';
import 'package:delivery_app/core/services/osrm_service.dart';
import 'package:delivery_app/core/utils/delivery_eta_calculator.dart';
import 'package:delivery_app/core/utils/delivery_fee_calculator.dart';
import 'package:delivery_app/features/customer/screens/create_order/controllers/order_quote_controller.dart';
import 'package:delivery_app/features/customer/screens/create_order/utils/traffic_demo_strings.dart';
import 'package:delivery_app/features/customer/screens/create_order/utils/delivery_eta_strings.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/order_location_controls.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/order_location_step.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/order_quote_step.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/traffic_demo_route_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:delivery_app/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:delivery_app/features/customer/screens/create_order/models/traffic_demo_scenario.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_StaticTestTiles.prepare);
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/traffic_demo_osrm_routes.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final at = DateTime.parse('2026-08-07T07:00:00+07:00');
  List<LatLng> points(String id) => (fixture[id]['points'] as List)
      .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
      .toList();
  OsrmRouteResult route(String id) => OsrmRouteResult(
    points: points(id),
    distanceMeters: (fixture[id]['distance'] as num).toDouble(),
    durationSeconds: (fixture[id]['duration'] as num).toDouble(),
  );
  DeliveryFeeEstimate quote(String id, TrafficDemoScenario scenario) =>
      DeliveryFeeCalculator.fromRoute(
        route: route(id),
        pickupLat: scenario.pickup.latitude,
        pickupLng: scenario.pickup.longitude,
        deliveryLat: scenario.delivery.latitude,
        deliveryLng: scenario.delivery.longitude,
        serviceType: 'standard',
        quotedAt: scenario.forecastAt,
      );
  double length(List<LatLng> points) {
    const distance = Distance();
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return meters;
  }

  double fraction(String id, bool Function(DeliveryTrafficLevel) match) {
    final segments = DeliveryTrafficRouteAnalyzer.analyze(
      routePoints: points(id),
      quotedAt: id == 'clear'
          ? TrafficDemoScenario.hcmHistoricClearTraffic.forecastAt
          : at,
    );
    final total = segments.fold(0.0, (sum, s) => sum + length(s.points));
    return segments
            .where((s) => match(s.level))
            .fold(0.0, (sum, s) => sum + length(s.points)) /
        total;
  }

  test(
    'clear demo is mostly green and never displays heavy or congested traffic',
    () {
      expect(
        fraction('clear', (level) => level == DeliveryTrafficLevel.clear),
        greaterThanOrEqualTo(0.90),
      );
      expect(
        fraction(
          'clear',
          (level) =>
              level == DeliveryTrafficLevel.heavy ||
              level == DeliveryTrafficLevel.congested,
        ),
        0,
      );
    },
  );
  test(
    'congested demo has substantially more orange and red road sections',
    () {
      expect(
        fraction(
          'congested',
          (level) =>
              level == DeliveryTrafficLevel.heavy ||
              level == DeliveryTrafficLevel.congested,
        ),
        greaterThanOrEqualTo(0.70),
      );
    },
  );
  test(
    'selectable scenarios use OSRM-confirmed equal distances at different demo hours',
    () {
      const jam = TrafficDemoScenario.hcmHistoricCongestion;
      const clear = TrafficDemoScenario.hcmHistoricClearTraffic;
      expect(jam.forecastAt, isNot(clear.forecastAt));
      for (final pair in [('congested', jam), ('clear', clear)]) {
        expect(fixture[pair.$1]['distance'], inInclusiveRange(2000, 3000));
        final c = fixture[pair.$1]['endpoints'];
        expect(pair.$2.pickup, LatLng(c[1], c[0]));
        expect(pair.$2.delivery, LatLng(c[3], c[2]));
      }
      expect(
        (fixture['congested']['distance'] - fixture['clear']['distance']).abs(),
        lessThan(10),
      );
    },
  );

  test(
    'whole-route LightGBM makes congestion slower at the same distance and price',
    () {
      final jam = quote('congested', TrafficDemoScenario.hcmHistoricCongestion);
      final clear = quote('clear', TrafficDemoScenario.hcmHistoricClearTraffic);
      expect(
        jam.distanceKm.toStringAsFixed(1),
        clear.distanceKm.toStringAsFixed(1),
      );
      expect(jam.deliveryFee, clear.deliveryFee);
      expect(jam.eta.usedAiCorrection, isTrue);
      expect(clear.eta.usedAiCorrection, isTrue);
      expect(
        jam.eta.baselineTravelMinutes,
        closeTo(jam.distanceKm / 25 * 60, 1e-9),
      );
      expect(
        clear.eta.baselineTravelMinutes,
        closeTo(clear.distanceKm / 25 * 60, 1e-9),
      );
      expect(
        jam.eta.minMinutes,
        greaterThanOrEqualTo(clear.eta.minMinutes + 2),
      );
      expect(
        jam.eta.maxMinutes,
        greaterThanOrEqualTo(clear.eta.maxMinutes + 2),
      );
    },
  );

  test('complete route coverage applies the weighted historical forecast', () {
    for (final pair in [
      ('congested', TrafficDemoScenario.hcmHistoricCongestion),
      ('clear', TrafficDemoScenario.hcmHistoricClearTraffic),
    ]) {
      final eta = quote(pair.$1, pair.$2).eta;
      expect(eta.usedAiCorrection, isTrue);
      expect(
        eta.calibratedTravelMinutes,
        closeTo(eta.rawAiTravelMinutes!, 1e-9),
      );
    }
  });

  test(
    'endpoint-only callers use speed directly without the old 55 percent blend',
    () {
      const scenario = TrafficDemoScenario.hcmHistoricCongestion;
      final calibration = DeliveryEtaAiCalibrator.calibrate(
        distanceKm: 5.6,
        baselineTravelMinutes: 12,
        pickupLat: scenario.pickup.latitude,
        pickupLng: scenario.pickup.longitude,
        deliveryLat: scenario.delivery.latitude,
        deliveryLng: scenario.delivery.longitude,
        isPeakHour: true,
        quotedAt: scenario.forecastAt,
      )!;
      expect(calibration.historicalTrafficMultiplier, greaterThan(1));
      expect(
        calibration.travelMinutes,
        closeTo(
          DeliveryEtaAiCalibrator.travelMinutesForDistance(
            5.6,
            scenario.forecastAt,
          )!,
          1e-9,
        ),
      );
    },
  );

  test(
    'reuses the map route and forecast time when continuing to the quote',
    () async {
      const scenario = TrafficDemoScenario.hcmHistoricCongestion;
      final expected = quote('congested', scenario);
      final actual =
          await OrderQuoteController(
            estimator:
                ({
                  required pickupLat,
                  required pickupLng,
                  required deliveryLat,
                  required deliveryLng,
                  required serviceType,
                }) => throw StateError('must reuse preview'),
          ).calculate(
            pickupLat: scenario.pickup.latitude,
            pickupLng: scenario.pickup.longitude,
            deliveryLat: scenario.delivery.latitude,
            deliveryLng: scenario.delivery.longitude,
            route: route('congested'),
            quotedAt: scenario.forecastAt,
          );
      expect(actual.distanceMeters, expected.distanceMeters);
      expect(actual.deliveryFee, expected.deliveryFee);
      expect(actual.eta.rangeLabel, expected.eta.rangeLabel);
    },
  );

  test(
    'does not claim complete AI coverage for a route leaving the dataset area',
    () {
      final eta = DeliveryEtaCalculator.calculate(
        distanceMeters: 5000,
        routeDurationSeconds: 1000,
        pickupLat: 10.775,
        pickupLng: 106.68,
        deliveryLat: 10.78,
        deliveryLng: 106.69,
        routePoints: const [
          LatLng(10.775, 106.68),
          LatLng(11.05, 106.68),
          LatLng(10.78, 106.69),
        ],
        quotedAt: at,
      );
      expect(eta.usedAiCorrection, isFalse);
      expect(
        eta.aiFallbackReason,
        'Chưa đủ dữ liệu giao thông trên toàn tuyến',
      );
      expect(eta.isPeakHour, isTrue);
    },
  );

  for (final config in [
    (const Size(390, 760), 1.0),
    (const Size(320, 600), 1.6),
    (const Size(1024, 768), 1.0),
  ]) {
    testWidgets(
      'map and quote wait for assignment at ${config.$1} / ${config.$2}',
      (tester) async {
        await tester.binding.setSurfaceSize(config.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final item in [
          ('congested', TrafficDemoScenario.hcmHistoricCongestion),
          ('clear', TrafficDemoScenario.hcmHistoricClearTraffic),
        ]) {
          final data = quote(item.$1, item.$2);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(config.$2)),
                child: Scaffold(
                  body: config.$1.width <= 320
                      ? Align(
                          alignment: Alignment.bottomCenter,
                          child: OrderLocationControlSheet(
                            pickupAddress: item.$2.pickupAddress,
                            deliveryAddress: item.$2.deliveryAddress,
                            pickupSelected: true,
                            deliverySelected: true,
                            route: route(item.$1),
                            eta: data.eta,
                            isLoadingRoute: false,
                            onPickPickup: () {},
                            onPickDelivery: () {},
                            onContinue: () {},
                            sampleRoutes: TrafficDemoRouteSelector(
                              selectedId: item.$2.id,
                              onApply: (_) {},
                            ),
                          ),
                        )
                      : OrderLocationStep(
                          initialCenter: item.$2.pickup,
                          pickup: item.$2.pickup,
                          delivery: item.$2.delivery,
                          pickupAddress: item.$2.pickupAddress,
                          deliveryAddress: item.$2.deliveryAddress,
                          quotedAt: item.$2.forecastAt,
                          osrm: _RecordedOsrm(route(item.$1)),
                          tileProvider: _StaticTestTiles(),
                          onPickPickup: () {},
                          onPickDelivery: () {},
                          onContinue: (_) {},
                          sampleRoutes: TrafficDemoRouteSelector(
                            selectedId: item.$2.id,
                            onApply: (_) {},
                          ),
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('2.8 km'), findsOneWidget);
          expect(find.text(DeliveryEtaStrings.afterAssignment), findsOneWidget);
          expect(find.text(data.eta.rangeLabel), findsNothing);
          expect(find.text(TrafficDemoStrings.forecastNote), findsOneWidget);
          expect(find.text('Cao điểm · 07:00'), findsOneWidget);
          expect(find.text('Ngoài cao điểm · 14:00'), findsOneWidget);
          if (find.byType(TileLayer).evaluate().isNotEmpty) {
            final camera = MapCamera.of(tester.element(find.byType(TileLayer)));
            final sheetTop = tester
                .getTopLeft(find.byType(OrderLocationControlSheet))
                .dy;
            for (final point in [item.$2.pickup, item.$2.delivery]) {
              final screen = camera.latLngToScreenPoint(point);
              expect(screen.y + 20, lessThan(sheetTop));
              expect(screen.y - 20, greaterThan(76));
              expect(screen.x, inInclusiveRange(20, config.$1.width - 20));
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(config.$2)),
                child: Scaffold(
                  body: OrderQuoteStep(
                    quote: data,
                    pickupAddress: item.$2.pickupAddress,
                    deliveryAddress: item.$2.deliveryAddress,
                    isTrafficDemo: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(data.eta.rangeLabel), findsNothing);
          expect(find.text(DeliveryEtaStrings.afterAssignment), findsOneWidget);
          expect(find.text(TrafficDemoStrings.forecastNote), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}

class _RecordedOsrm extends OsrmService {
  _RecordedOsrm(this.route);
  final OsrmRouteResult route;

  @override
  Future<OsrmRouteResult?> getRouteWithWaypoints({
    required List<LatLng> waypoints,
  }) async => route;
}

class _StaticTestTiles extends TileProvider {
  static late MemoryImage _image;

  static Future<void> prepare() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0x00000000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    _image = MemoryImage(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _image;
}
