import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:giaohang_mobile/core/ml/eta_simulation/model.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/profile.dart';
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/services/eta_forecast_service.dart';
import 'package:giaohang_mobile/core/services/osrm_service.dart';
import 'package:giaohang_mobile/core/utils/delivery_eta_calculator.dart';
import 'package:giaohang_mobile/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:giaohang_mobile/core/widgets/delivery_traffic_map_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'helpers/utraffic_capture_fonts.dart';

dynamic read(String path) => jsonDecode(File(path).readAsStringSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('ETA_SIMULATION_CAPTURE')) {
      await prepareUtrafficCaptureFonts();
    }
  });
  final model = EtaCorrectionModel(read('assets/ml/eta_simulation_model.json'));
  final context = Map<String, dynamic>.from(
    read('assets/ml/eta_simulation_context.json'),
  );
  final cases = read('test/fixtures/eta_simulation_profiles.json') as List;

  test(
    'exported Dart trees reproduce 1000 held-out Python LightGBM predictions',
    () {
      for (final fixture
          in read('test/fixtures/eta_simulation_vectors.json') as List) {
        final vector = (fixture['features'] as List)
            .map((v) => (v as num).toDouble())
            .toList();
        expect(
          model.predict(vector),
          closeTo(fixture['expected_speed_kmh'], 1e-8),
        );
      }
    },
  );

  test('AI speeds share one duration across GPS, map and preview', () {
    for (final fixture in cases) {
      final route = Map<String, dynamic>.from(fixture['route']),
          at = fixture['at'] as String;
      final raw = buildEtaProfile(route, at, model, context);
      final profile = DeliveryEtaRouteProfile.fromJson(raw)!;
      expect(profile.usesAi, isTrue);
      expect(profile.isSynthetic, isTrue);
      expect(profile.modelVersion, EtaForecastService.modelVersion);
      expect(
        profile.datasetLabel,
        fixture['expected_profile']['dataset_label'],
      );
      expect(
        profile.datasetScope,
        fixture['expected_profile']['dataset_scope'],
      );
      expect(raw['lightgbm_travel_minutes'], isNull);
      expect(profile.sections.first.startMeters, 0);
      expect(profile.sections.last.endMeters, route['distance']);
      final eta = DeliveryEtaCalculator.calculate(
        distanceMeters: profile.distanceMeters,
        routeDurationSeconds: (route['duration'] as num).toDouble(),
        quotedAt: profile.forecastAt,
        routePoints: profile.points,
        speedProfile: profile,
      );
      expect(eta.usedRouteDuration, isTrue);
      expect(eta.aiDatasetLabel, 'AI · ETA mô phỏng TP.HCM');
      expect(eta.usedAiCorrection, isTrue);
      expect(eta.rawAiTravelMinutes, eta.calibratedTravelMinutes);
      expect(eta.aiModelVersion, EtaForecastService.modelVersion);
      expect(
        eta.baselineTravelMinutes,
        closeTo((route['duration'] as num) / 60, 1e-8),
      );
      expect(
        eta.calibratedTravelMinutes,
        closeTo((raw['travel_minutes'] as num).toDouble(), 1e-8),
      );
      expect(
        profile.remainingMinutes(profile.points.first),
        closeTo(eta.calibratedTravelMinutes, 1e-8),
      );
      final colors = profile.trafficSegments;
      final expected = fixture['expected_profile']['speed_profile'] as List;
      expect(profile.sections.length, expected.length);
      for (var i = 0; i < profile.sections.length; i++) {
        final section = profile.sections[i];
        expect(section.speedKmh, closeTo(expected[i]['speed_kmh'], 1e-8));
        expect(section.startMeters, closeTo(expected[i]['start_meters'], 1e-6));
        expect(section.endMeters, closeTo(expected[i]['end_meters'], 1e-6));
        expect(
          section.referenceSpeedKmh,
          closeTo(expected[i]['reference_speed_kmh'], 1e-8),
        );
        expect(section.speedKmh, inInclusiveRange(15, 50));
      }
      expect(colors.length, lessThanOrEqualTo(profile.sections.length));
      expect(colors.every((s) => s.isSynthetic), isTrue);
      for (var i = 1; i < colors.length; i++) {
        expect(colors[i].level, isNot(colors[i - 1].level));
      }
    }
  });

  test(
    'cached old previews are rebuilt with trained version-six profiles',
    () async {
      final assets = _CountingAssets();
      final counted = EtaForecastService(assets: assets);
      addTearDown(counted.dispose);
      final fixture = cases.first, raw = fixture['route'];
      final oldProfile = Map<String, dynamic>.from(fixture['expected_profile'])
        ..['profile_version'] = 1;
      final parsed = DeliveryEtaRouteProfile.fromJson(oldProfile)!;
      final route = OsrmRouteResult(
        points: parsed.points,
        distanceMeters: parsed.distanceMeters,
        durationSeconds: (raw['duration'] as num).toDouble(),
        forecastProfile: oldProfile,
      );
      final result = await counted.forecast(
        route,
        DateTime.parse(fixture['at']),
      );
      expect(result.forecastProfile!['profile_version'], 6);
      expect(result.forecastProfile, isNot(same(oldProfile)));
      expect(assets.loads, 2);
      expect(result.forecastProfile!['used_ai'], isTrue);
    },
  );

  test(
    'outside the demo domain remains a routing estimate without an AI claim',
    () {
      final original = Map<String, dynamic>.from(cases.first['route']);
      final route = {
        ...original,
        'geometry': {
          'coordinates': [
            [105.7, 21.05],
            [105.72, 21.06],
          ],
        },
      };
      final raw = buildEtaProfile(route, cases.first['at'], model, context);
      expect(raw['used_ai'], isFalse);
      expect(
        (raw['travel_minutes'] as num) * 60,
        closeTo(route['duration'], 1e-6),
      );
      expect(
        DeliveryEtaRouteProfile.fromJson(raw)!.trafficSegments.every(
          (s) => s.level == DeliveryTrafficLevel.unavailable,
        ),
        isTrue,
      );
    },
  );

  test(
    'missing road-node detail still uses AI with fallback road features',
    () {
      final fixture = cases.first;
      final raw = buildEtaProfile(
        Map<String, dynamic>.from(fixture['route']),
        fixture['at'],
        model,
        {...context, 'speed_roads': null},
      );
      final profile = DeliveryEtaRouteProfile.fromJson(raw)!;
      expect(profile.usesAi, isTrue);
      expect(
        profile.trafficSegments.every(
          (s) => s.level != DeliveryTrafficLevel.unavailable,
        ),
        isTrue,
      );
      expect(
        profile.remainingMinutes(profile.points.first),
        closeTo(raw['travel_minutes'], 1e-8),
      );
    },
  );

  test(
    'native worker loads two assets once and caches the same route/clock',
    () async {
      final assets = _CountingAssets();
      final counted = EtaForecastService(assets: assets);
      addTearDown(counted.dispose);
      final fixture = cases.first, raw = fixture['route'];
      final annotation = raw['legs'][0]['annotation'];
      final route = OsrmRouteResult(
        points: (raw['geometry']['coordinates'] as List)
            .map(
              (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
            )
            .toList(),
        distanceMeters: (raw['distance'] as num).toDouble(),
        durationSeconds: (raw['duration'] as num).toDouble(),
        annotationNodes: (annotation['nodes'] as List)
            .map((n) => (n as num).toInt())
            .toList(),
        annotationDistances: (annotation['distance'] as List)
            .map((n) => (n as num).toDouble())
            .toList(),
        annotationDurations: (annotation['duration'] as List)
            .map((n) => (n as num).toDouble())
            .toList(),
      );
      final at = DateTime.parse(fixture['at']);
      final first = await counted.forecast(route, at),
          repeated = await counted.forecast(route, at);
      expect(first.forecastProfile, same(repeated.forecastProfile));
      expect(first.forecastProfile!['used_ai'], isTrue);
      expect(
        first.forecastProfile!['travel_minutes'],
        closeTo(fixture['expected_profile']['travel_minutes'], 1e-8),
      );
      await counted.forecast(route, at.add(const Duration(hours: 1)));
      expect(assets.loads, 2);
    },
  );

  test(
    'missing model assets preserve the supplied routing time for fallback',
    () async {
      final service = EtaForecastService(assets: _MissingAssets());
      addTearDown(service.dispose);
      const route = OsrmRouteResult(
        points: [LatLng(10.77, 106.68), LatLng(10.78, 106.69)],
        distanceMeters: 1500,
        durationSeconds: 240,
      );
      final result = await service.forecast(route, DateTime.utc(2026, 10, 12));
      final profile = DeliveryEtaRouteProfile.fromJson(result.forecastProfile)!;
      expect(profile.usesAi, isFalse);
      expect(profile.remainingMinutes(profile.points.first), closeTo(4, 1e-8));
      expect(
        profile.trafficSegments.single.level,
        DeliveryTrafficLevel.unavailable,
      );
    },
  );

  for (final size in [const Size(320, 240), const Size(390, 240)]) {
    testWidgets('AI legend shows absolute speed bands at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final profile = DeliveryEtaRouteProfile.fromJson(
        cases.last['expected_profile'],
      )!;
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
                child: DeliveryTrafficMapLegend(
                  segments: profile.trafficSegments,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Tốc độ AI dự đoán · km/h'), findsOneWidget);
      expect(find.text('Nhanh ≥35'), findsOneWidget);
      expect(find.text('Vừa 25–<35'), findsOneWidget);
      expect(find.text('Chậm 20–<25'), findsOneWidget);
      expect(find.text('Chậm hơn 15–<20'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('ETA_SIMULATION_CAPTURE')) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '../../output/eta_simulation/ui/legend-${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _CountingAssets extends CachingAssetBundle {
  int loads = 0;
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loads++;
    return File(
      key.replaceFirst('packages/giaohang_mobile/', ''),
    ).readAsString();
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

class _MissingAssets extends _CountingAssets {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      throw StateError('model unavailable');
}
