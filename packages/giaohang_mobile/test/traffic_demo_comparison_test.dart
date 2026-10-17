import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/services/osrm_service.dart';
import 'package:giaohang_mobile/core/utils/delivery_eta_calculator.dart';
import 'package:giaohang_mobile/core/utils/delivery_fee_calculator.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/controllers/order_quote_controller.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/traffic_demo_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/delivery_eta_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_location_controls.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_location_step.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_quote_step.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/traffic_demo_route_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:giaohang_mobile/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/models/traffic_demo_scenario.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'helpers/utraffic_capture_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('UTRAFFIC_CAPTURE')) {
    setUpAll(prepareUtrafficCaptureFonts);
  }
  setUpAll(_StaticTestTiles.prepare);
  final fixture =
      jsonDecode(File('test/fixtures/utraffic_demo.json').readAsStringSync())
          as Map<String, dynamic>;
  final at = TrafficDemoScenario.hcmHistoricCongestion.forecastAt;
  List<LatLng> points(String id) => (fixture[id]['points'] as List)
      .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
      .toList();
  OsrmRouteResult route(String id) => OsrmRouteResult(
    points: points(id),
    distanceMeters: (fixture[id]['distance'] as num).toDouble(),
    durationSeconds: (fixture[id]['duration'] as num).toDouble(),
    forecastProfile: fixture[id]['profile'],
    annotationNodes: (fixture[id]['nodes'] as List)
        .map((n) => (n as num).toInt())
        .toList(),
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
      profile: DeliveryEtaRouteProfile.fromJson(fixture[id]['profile']),
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
    'model output changes traffic coverage without forcing the clear scenario green',
    () {
      final slow = fraction(
        'congested',
        (l) => l == DeliveryTrafficLevel.congested,
      );
      final fast = fraction(
        'clear',
        (l) => l == DeliveryTrafficLevel.congested,
      );
      expect(slow, greaterThan(fast));
      for (final level in [
        DeliveryTrafficLevel.clear,
        DeliveryTrafficLevel.moderate,
      ]) {
        expect(
          fraction('clear', (l) => l == level) * fixture['clear']['distance'],
          greaterThan(200),
          reason:
              'Each predicted color needs a visible section on the short demo',
        );
      }
      expect(
        fraction('congested', (l) => l == DeliveryTrafficLevel.heavy) *
            fixture['congested']['distance'],
        greaterThan(200),
      );
      for (final id in ['congested', 'clear']) {
        expect(
          fraction(id, (l) => l == DeliveryTrafficLevel.unavailable),
          closeTo(0, 1e-9),
        );
        expect(
          fraction(id, (l) => l != DeliveryTrafficLevel.unavailable),
          closeTo(1, 1e-9),
        );
      }
    },
  );
  test(
    'selectable scenarios use OSRM-confirmed equal distances at different demo hours',
    () {
      const jam = TrafficDemoScenario.hcmHistoricCongestion;
      const clear = TrafficDemoScenario.hcmHistoricClearTraffic;
      expect(jam.forecastAt, isNot(clear.forecastAt));
      for (final pair in [('congested', jam), ('clear', clear)]) {
        expect(fixture[pair.$1]['distance'], inInclusiveRange(500, 1000));
        final c = fixture[pair.$1]['endpoints'];
        expect(pair.$2.pickup, LatLng(c[1], c[0]));
        expect(pair.$2.delivery, LatLng(c[3], c[2]));
      }
      expect(
        (fixture['congested']['distance'] - fixture['clear']['distance']).abs(),
        lessThan(10),
      );
      expect(fixture['congested']['points'], fixture['clear']['points']);
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
        greaterThanOrEqualTo(clear.eta.minMinutes + 1),
      );
      expect(
        jam.eta.maxMinutes,
        greaterThanOrEqualTo(clear.eta.maxMinutes + 1),
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

  test('coordinates alone do not invent a directed road forecast', () {
    final eta = DeliveryEtaCalculator.calculate(
      distanceMeters: 5600,
      pickupLat: 10.7849,
      pickupLng: 106.6684,
      deliveryLat: 10.8505,
      deliveryLng: 106.7421,
      quotedAt: at,
    );
    expect(eta.usedAiCorrection, isFalse);
    expect(eta.calibratedTravelMinutes, closeTo(5.6 / 25 * 60, 1e-9));
  });
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
      expect(eta.aiFallbackReason, 'Chưa có dự báo vận tốc cho tuyến này');
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
          await _pumpCaptured(
            tester,
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
                            isLoadingRoute: false,
                            onPickPickup: () {},
                            onPickDelivery: () {},
                            onContinue: () {},
                            sampleRoutes: TrafficDemoRouteSelector(
                              selectedId: item.$2.id,
                              onApply: (_) {},
                              onUseSampleRoute: () {},
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
                            onUseSampleRoute: () {},
                          ),
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (const bool.fromEnvironment('UTRAFFIC_CAPTURE')) {
            await tester.runAsync(
              () => _savePreview('${config.$1.width.toInt()}_${item.$1}'),
            );
          }
          expect(find.text('0.6 km'), findsNothing);
          expect(find.text('Ngoài vùng'), findsNothing);
          expect(find.text('Ngoài vùng demo AI · tuyến OSRM'), findsNothing);
          expect(find.text(DeliveryEtaStrings.afterAssignment), findsNothing);
          expect(find.text(data.eta.rangeLabel), findsNothing);
          expect(find.text(TrafficDemoStrings.forecastNote), findsNothing);
          expect(find.text('Cao điểm · 18:00'), findsOneWidget);
          expect(find.text('Ngoài cao điểm · 12:00'), findsOneWidget);
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
          await _pumpCaptured(
            tester,
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

final _captureKey = GlobalKey();
Future<void> _pumpCaptured(WidgetTester tester, Widget child) =>
    tester.pumpWidget(RepaintBoundary(key: _captureKey, child: child));
Future<void> _savePreview(String name) async {
  final boundary =
      _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  const directory = String.fromEnvironment(
    'UTRAFFIC_CAPTURE_DIR',
    defaultValue: 'ui',
  );
  final file = File('../../output/utraffic_speed/$directory/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}
