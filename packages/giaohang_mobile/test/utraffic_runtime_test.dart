import 'dart:convert';
import 'dart:io';

import 'package:giaohang_mobile/core/ml/utraffic/model.dart';
import 'package:giaohang_mobile/core/ml/utraffic/matcher.dart';
import 'package:giaohang_mobile/core/ml/utraffic/profile.dart';
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/services/osrm_service.dart';
import 'package:giaohang_mobile/core/services/utraffic_forecast_service.dart';
import 'package:giaohang_mobile/core/utils/delivery_eta_calculator.dart';
import 'package:giaohang_mobile/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

dynamic read(String path) => jsonDecode(File(path).readAsStringSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SpeedModel model;
  late RoadMatcher matcher;
  final demo = read('test/fixtures/utraffic_demo.json') as Map;
  final assignment = read('test/fixtures/utraffic_demo_assignment.json') as Map;
  final fixtures = [
    ...read('test/fixtures/utraffic_route_parity.json') as List,
    for (final entry in demo.entries)
      {
        'at': entry.value['profile']['forecast_at'],
        'expected': entry.value['profile'],
        'route': {
          'distance': entry.value['distance'],
          'geometry': {'coordinates': entry.value['points']},
          'legs': [
            {
              'annotation': {'nodes': entry.value['nodes']},
            },
          ],
        },
      },
    for (final scenario in assignment.values)
      for (final leg in ['approach', 'delivery'])
        {
          'at': scenario[leg]['forecast_at'],
          'expected': scenario[leg],
          'route': scenario['routes'][leg],
        },
  ];
  setUpAll(() {
    model = SpeedModel(read('assets/ml/utraffic_model.json'));
    matcher = RoadMatcher(read('assets/ml/utraffic_network.json'));
  });
  test('production Dart matches 2720 frozen LightGBM speed expectations', () {
    for (final c in read('test/fixtures/utraffic_parity.json') as List) {
      final road = (c['road'] as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      );
      final features = model.featuresAt(road, c['at']);
      for (var i = 0; i < features.length; i++) {
        expect(features[i], closeTo(c['features'][i], 1e-10));
      }
      expect(model.predict(features), closeTo(c['speed_kmh'], 1e-8));
    }
  });
  test(
    'production route, map, GPS and ETA agree with Python at 16 forecast times',
    () {
      for (final c in fixtures) {
        final actual = buildRouteSpeedProfile(
          c['route'],
          c['at'],
          model,
          matcher,
        );
        final expected = c['expected'];
        expect(
          actual['travel_minutes'],
          closeTo(expected['travel_minutes'], 1e-6),
        );
        final sections = actual['speed_profile'] as List;
        expect(sections.length, (expected['speed_profile'] as List).length);
        final profile = DeliveryEtaRouteProfile.fromJson(actual)!;
        final eta = DeliveryEtaCalculator.calculate(
          distanceMeters: profile.distanceMeters,
          quotedAt: profile.forecastAt,
          routePoints: profile.points,
          speedProfile: profile,
        );
        expect(
          eta.calibratedTravelMinutes,
          closeTo(actual['travel_minutes'], 1e-8),
        );
        final colors = profile.trafficSegments;
        for (var i = 0; i < sections.length; i++) {
          final section = sections[i], reference = expected['speed_profile'][i];
          expect(section['segment_id'], reference['segment_id']);
          expect(section['used_ai'], reference['used_ai']);
          expect(section['speed_kmh'], closeTo(reference['speed_kmh'], 1e-8));
          expect(
            profile.speedAtDistance(
              (section['start_meters'] + section['end_meters']) / 2,
            ),
            section['speed_kmh'],
          );
          if (section['used_ai'] == false) {
            expect(colors[i].level, DeliveryTrafficLevel.unavailable);
          }
        }
      }
    },
  );
  test(
    'native worker loads assets once, shares preview and invalidates a different clock',
    () async {
      final c = fixtures.first;
      final raw = c['route'];
      final route = OsrmRouteResult(
        points: (raw['geometry']['coordinates'] as List)
            .map(
              (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
            )
            .toList(),
        distanceMeters: (raw['distance'] as num).toDouble(),
        durationSeconds: 0,
        annotationNodes: (raw['legs'][0]['annotation']['nodes'] as List)
            .map((n) => (n as num).toInt())
            .toList(),
      );
      final assets = _CountingAssets();
      final service = UtrafficForecastService(assets: assets);
      addTearDown(service.dispose);
      final at = DateTime.parse(c['at']);
      final result = await service.forecast(route, at);
      expect(result.forecastProfile!['used_ai'], isTrue);
      expect(
        result.forecastProfile!['travel_minutes'],
        closeTo(c['expected']['travel_minutes'], 1e-6),
      );
      expect(identical(await service.forecast(result, at), result), isTrue);
      final changed = await service.forecast(
        result,
        at.add(const Duration(hours: 5)),
      );
      expect(
        changed.forecastProfile!['forecast_at'],
        isNot(result.forecastProfile!['forecast_at']),
      );
      expect(changed.points, same(result.points));
      expect(assets.loads, 2);
    },
  );
  test('failed asset loading gives one consistent 25 km/h fallback', () async {
    final service = UtrafficForecastService(assets: _MissingAssets());
    addTearDown(service.dispose);
    const route = OsrmRouteResult(
      points: [LatLng(10.77, 106.68), LatLng(10.78, 106.69)],
      distanceMeters: 1500,
      durationSeconds: 1,
    );
    final result = await service.forecast(route, DateTime.utc(2026, 10, 12));
    final profile = DeliveryEtaRouteProfile.fromJson(result.forecastProfile)!;
    expect(profile.usesAi, isFalse);
    expect(profile.speedAtDistance(700), 25);
    expect(result.forecastProfile!['travel_minutes'], 3.6);
    expect(
      profile.trafficSegments.single.level,
      DeliveryTrafficLevel.unavailable,
    );
  });
}

class _CountingAssets extends CachingAssetBundle {
  int loads = 0;
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loads++;
    return File(key).readAsString();
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

class _MissingAssets extends _CountingAssets {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      throw StateError('fixture missing');
}
