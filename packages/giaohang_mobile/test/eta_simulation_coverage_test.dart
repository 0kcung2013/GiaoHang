import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_mobile/core/constants/eta_simulation_strings.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/coverage.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/model.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/profile.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/segment_speeds.dart';
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/services/eta_forecast_service.dart';
import 'package:giaohang_mobile/core/services/osrm_service.dart';
import 'package:giaohang_mobile/core/utils/delivery_eta_calculator.dart';
import 'package:giaohang_mobile/core/utils/delivery_fee_calculator.dart';
import 'package:giaohang_mobile/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:giaohang_mobile/core/widgets/delivery_traffic_map_layer.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/eta_ai_detail_panel.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_location_step.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/traffic_aware_order_route_layer.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/utraffic_capture_fonts.dart';
import 'support/return_map_test_tiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final context = Map<String, dynamic>.from(
    jsonDecode(
      File('assets/ml/eta_simulation_context.json').readAsStringSync(),
    ),
  );
  final model = EtaCorrectionModel(
    jsonDecode(File('assets/ml/eta_simulation_model.json').readAsStringSync()),
  );
  final at = DateTime.utc(2026, 10, 17, 5);

  Map<String, dynamic> input(List<List<double>> points) => {
    'distance': 1500.0,
    'duration': 240.0,
    'geometry': {'coordinates': points},
  };

  // In the former expanded demo rectangle, beyond the training graph's north.
  final outside = input([
    [106.67, 11.00],
    [106.672, 11.00],
    [106.672, 10.995],
  ]);

  OsrmRouteResult oldAiPreview() =>
      const OsrmRouteResult(
        points: [
          LatLng(11.00, 106.67),
          LatLng(11.00, 106.672),
          LatLng(10.995, 106.672),
        ],
        distanceMeters: 1500,
        durationSeconds: 240,
      ).withForecast({
        'model_version': EtaForecastService.modelVersion,
        'profile_version': EtaForecastService.profileVersion,
        'coverage_version': EtaSimulationCoverage.version,
        'forecast_at': at.toIso8601String(),
        'distance_meters': 1500,
        'baseline_seconds': 240,
        'route_points': (outside['geometry'] as Map)['coordinates'],
        'used_ai': true,
        'is_synthetic': true,
        'color_metric': 'speed_kmh',
        'speed_profile': [
          {
            'start_meters': 0,
            'end_meters': 1500,
            'speed_kmh': 45,
            'used_ai': true,
            'traffic_available': true,
          },
        ],
      });

  test(
    'coverage matches the actual training context, not expanded OSM data',
    () {
      expect(context['bounds'], {
        'min_lat': EtaSimulationCoverage.minLatitude,
        'max_lat': EtaSimulationCoverage.maxLatitude,
        'min_lng': EtaSimulationCoverage.minLongitude,
        'max_lng': EtaSimulationCoverage.maxLongitude,
      });
      expect(
        supportsSpeedSimulation(
          input([
            [106.50, 10.65],
            [106.90, 10.95],
          ]),
        ),
        isTrue,
      );
    },
  );

  for (final edge in <String, List<double>>{
    'north': [106.67, 10.95001],
    'south': [106.67, 10.64999],
    'east': [106.90001, 10.8],
    'west': [106.49999, 10.8],
  }.entries) {
    test(
      'a route crossing the ${edge.key} boundary uses OSRM for its entirety',
      () {
        final route = input([
          [106.67, 10.8],
          edge.value,
          [106.68, 10.81],
        ]);
        final raw = buildEtaProfile(
          route,
          at.toIso8601String(),
          model,
          context,
        );
        expect(raw['used_ai'], isFalse);
        expect(raw['all_sections_ai'], isFalse);
        expect(raw['ai_coverage_ratio'], 0);
        expect(raw['fallback_reason'], EtaSimulationCoverage.outsideReason);
        expect(raw['travel_minutes'], 4);
        final profile = DeliveryEtaRouteProfile.fromJson(raw)!;
        expect(profile.sections, hasLength(1));
        expect(
          profile.trafficSegments.single.level,
          DeliveryTrafficLevel.unavailable,
        );
        expect(
          deliveryTrafficColor(profile.trafficSegments.single.level),
          AppColors.routeLine,
        );
        expect(
          profile.remainingMinutes(profile.points.first),
          closeTo(4, 1e-8),
        );
      },
    );
  }

  test(
    'outside forecast replaces a cached AI preview without loading model assets',
    () async {
      final assets = _UnavailableAssets();
      final service = EtaForecastService(assets: assets);
      addTearDown(service.dispose);
      final old = oldAiPreview();
      expect(EtaForecastService.canReuseForecast(old, at), isFalse);
      final result = await service.forecast(old, at);
      expect(assets.loads, 0);
      expect(result.forecastProfile!['used_ai'], isFalse);
      expect(result.forecastProfile!['travel_minutes'], 4);
      expect(EtaForecastService.canReuseForecast(result, at), isTrue);
      expect(await service.forecast(result, at), same(result));
    },
  );

  test(
    'fee preview also discards cached AI outside coverage and keeps OSRM time',
    () async {
      final route = oldAiPreview();
      final quote = await DeliveryFeeCalculator.fromRoadRoute(
        route: route,
        pickupLat: route.points.first.latitude,
        pickupLng: route.points.first.longitude,
        deliveryLat: route.points.last.latitude,
        deliveryLng: route.points.last.longitude,
        serviceType: 'standard',
        quotedAt: at,
      );
      expect(quote.eta.usedAiCorrection, isFalse);
      expect(quote.eta.calibratedTravelMinutes, closeTo(4, 1e-8));
      expect(quote.eta.aiFallbackReason, EtaSimulationStrings.outsideCoverage);
    },
  );

  setUpAll(() async {
    await prepareUtrafficCaptureFonts();
    await ReturnMapTestTiles.prepare();
  });

  for (final config in [
    (const Size(320, 568), 1.6),
    (const Size(390, 760), 1.0),
    (const Size(1024, 768), 1.0),
  ]) {
    testWidgets(
      'outside map uses a blue route and OSRM notice at ${config.$1}',
      (tester) async {
        await tester.binding.setSurfaceSize(config.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final old = oldAiPreview();
        OsrmRouteResult? continued;
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(config.$2)),
                child: Scaffold(
                  body: OrderLocationStep(
                    initialCenter: old.points.first,
                    pickup: old.points.first,
                    delivery: old.points.last,
                    pickupAddress: 'Điểm lấy hàng ngoài vùng AI',
                    deliveryAddress: 'Điểm giao hàng ngoài vùng AI',
                    onPickPickup: () {},
                    onPickDelivery: () {},
                    onContinue: (route) => continued = route,
                    quotedAt: at,
                    osrm: _FixedRoute(old),
                    tileProvider: ReturnMapTestTiles(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(EtaSimulationStrings.outsideCoverage), findsOneWidget);
        expect(find.text(EtaSimulationStrings.legendTitle), findsNothing);
        final layer = tester.widget<TrafficAwareOrderRouteLayer>(
          find.byType(TrafficAwareOrderRouteLayer),
        );
        expect(layer.profile!.usesAi, isFalse);
        final lines = TrafficAwareOrderRouteLayer.polylinesFor(
          routePoints: layer.routePoints,
          quotedAt: at,
          profile: layer.profile,
        );
        expect(
          lines.skip(1).every((line) => line.color == AppColors.routeLine),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('ETA_SIMULATION_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '../../.tmp/eta-coverage/outside-${config.$1.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('Tiếp tục'));
        expect(continued!.forecastProfile!['used_ai'], isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'legend and ETA details distinguish outside coverage from missing model',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final raw = buildEtaProfile(
        outside,
        at.toIso8601String(),
        model,
        context,
      );
      final profile = DeliveryEtaRouteProfile.fromJson(raw)!;
      final eta = DeliveryEtaCalculator.calculate(
        distanceMeters: profile.distanceMeters,
        routeDurationSeconds: 240,
        quotedAt: at,
        routePoints: profile.points,
        speedProfile: profile,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    DeliveryTrafficMapLegend(segments: profile.trafficSegments),
                    EtaAiDetailPanel(eta: eta),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text(EtaSimulationStrings.outsideCoverage), findsNWidgets(2));
      expect(find.text(EtaSimulationStrings.legendTitle), findsNothing);
      expect(tester.takeException(), isNull);

      final missing = DeliveryEtaRouteProfile.fromJson({
        ...raw,
        'fallback_reason': 'model_unavailable',
      })!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryTrafficMapLegend(segments: missing.trafficSegments),
          ),
        ),
      );
      expect(find.text(EtaSimulationStrings.routingEstimate), findsOneWidget);
      expect(find.text(EtaSimulationStrings.outsideCoverage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _UnavailableAssets extends CachingAssetBundle {
  int loads = 0;
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loads++;
    throw StateError('No assets');
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

class _FixedRoute extends OsrmService {
  _FixedRoute(this.route);
  final OsrmRouteResult route;
  @override
  Future<OsrmRouteResult?> getRouteWithWaypoints({
    required List<LatLng> waypoints,
  }) async => route;
}
