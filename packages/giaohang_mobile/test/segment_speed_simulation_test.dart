import 'dart:convert';
import 'dart:io';
import 'package:giaohang_mobile/core/ml/eta_simulation/features.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/model.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/profile.dart';
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final model = EtaCorrectionModel(
    jsonDecode(File('assets/ml/eta_simulation_model.json').readAsStringSync()),
  );
  final context = Map<String, dynamic>.from(
    jsonDecode(
      File('assets/ml/eta_simulation_context.json').readAsStringSync(),
    ),
  );
  const at = '2026-10-07T18:00:00+07:00', noon = '2026-10-07T12:00:00+07:00';
  Map<String, dynamic> route(List<List<double>> points, {double? duration}) {
    final meters = List.generate(
      points.length - 1,
      (i) => etaDistance(points[i], points[i + 1]),
    ).fold(0.0, (a, b) => a + b);
    return {
      'distance': meters,
      'duration': duration ?? meters * .144,
      'geometry': {'coordinates': points},
      'legs': [],
    };
  }

  test(
    'shared road features retain speeds when route endpoints and total duration change',
    () {
      final a = route([
        [106.6001, 10.7503],
        [106.6409, 10.7503],
      ]);
      final b = route([
        [106.5982, 10.7503],
        [106.6205, 10.7503],
        [106.6462, 10.7503],
      ], duration: 160);
      final shared = {
        for (final s in buildEtaProfile(b, at, model, context)['speed_profile'])
          s['segment_id']: s['speed_kmh'],
      };
      for (final s in buildEtaProfile(a, at, model, context)['speed_profile']) {
        expect(s['speed_kmh'], shared[s['segment_id']]);
      }
    },
  );
  test(
    'unknown short and long suburban roads use AI and respect 15 km/h floor',
    () {
      for (final r in [
        route([
          [106.5, 11.15],
          [106.52, 11.17],
        ]),
        route([
          [106.6, 10.75],
          [106.9, 10.6],
          [107.2, 10.7],
        ]),
        route([
          [106.6, 10.75],
          [106.60001, 10.75001],
        ]),
      ]) {
        final raw = buildEtaProfile(r, at, model, {
          ...context,
          'cells': {},
          'speed_roads': null,
        });
        final p = DeliveryEtaRouteProfile.fromJson(raw)!;
        expect(p.usesAi, isTrue);
        expect(
          p.sections.every((s) => s.speedKmh >= 15 && s.speedKmh <= 50),
          isTrue,
        );
        expect(
          p.remainingMinutes(p.points.first),
          closeTo(raw['travel_minutes'], 1e-8),
        );
        expect(
          p.trafficSegments.every(
            (s) => s.level != DeliveryTrafficLevel.unavailable,
          ),
          isTrue,
        );
      }
    },
  );
  test('peak ETA is longer and repeated forecasts remain deterministic', () {
    final r = route([
      [106.62, 10.78],
      [106.68, 10.79],
      [106.7, 10.85],
    ]);
    final peak = buildEtaProfile(r, at, model, context),
        off = buildEtaProfile(r, noon, model, context);
    expect(peak['travel_minutes'], greaterThan(off['travel_minutes']));
    expect(peak, buildEtaProfile(r, at, model, context));
  });
  test(
    'alleys and clear arterial roads have different absolute speed colors',
    () {
      final r = route([
        [106.6001, 10.7503],
        [106.6029, 10.7503],
      ]);
      Map<String, dynamic> withSpeed(double speed) => {
        ...r,
        'legs': [
          {
            'annotation': {
              'distance': [r['distance']],
              'duration': [(r['distance'] as num) * 3.6 / speed],
            },
          },
        ],
      };
      final narrow = DeliveryEtaRouteProfile.fromJson(
        buildEtaProfile(withSpeed(15), noon, model, context),
      )!;
      final wide = DeliveryEtaRouteProfile.fromJson(
        buildEtaProfile(withSpeed(50), noon, model, context),
      )!;
      expect(
        narrow.trafficSegments.every(
          (s) => s.level == DeliveryTrafficLevel.heavy,
        ),
        isTrue,
      );
      expect(
        wide.trafficSegments.every(
          (s) => s.level == DeliveryTrafficLevel.clear,
        ),
        isTrue,
      );
      expect(
        narrow.remainingMinutes(narrow.points.first),
        greaterThan(wide.remainingMinutes(wide.points.first)),
      );
    },
  );
  test(
    'same-color AI sections merge visually while movement keeps each learned speed',
    () {
      final p = DeliveryEtaRouteProfile.fromJson({
        'distance_meters': 300,
        'route_points': [
          [106.6, 10.75],
          [106.603, 10.75],
        ],
        'forecast_at': at,
        'used_ai': true,
        'is_synthetic': true,
        'color_metric': 'speed_kmh',
        'speed_profile': [
          {'start_meters': 0, 'end_meters': 100, 'speed_kmh': 36},
          {'start_meters': 100, 'end_meters': 200, 'speed_kmh': 40},
          {'start_meters': 200, 'end_meters': 300, 'speed_kmh': 18},
        ],
      })!;
      const start = LatLng(10.75, 106.6);
      expect(p.trafficSegments, hasLength(2));
      expect(p.trafficSegments.first.distanceMeters, 200);
      expect(p.sections, hasLength(3));
      expect(
        p.metersForDuration(start, const Duration(seconds: 19)),
        closeTo(200, 1e-8),
      );
      expect(
        p.metersForDuration(start, const Duration(seconds: 24)),
        closeTo(225, 1e-8),
      );
      expect(
        p.metersForDuration(start, const Duration(seconds: 39)),
        closeTo(300, 1e-8),
      );
      expect(p.remainingMinutes(start) * 60, closeTo(39, 1e-8));
      expect(p.trafficLevelAt(p.points.last), DeliveryTrafficLevel.congested);
    },
  );
  test('simulated arrival matches primary AI ETA for every fixture', () {
    final fixtures =
        jsonDecode(
              File(
                'test/fixtures/eta_simulation_profiles.json',
              ).readAsStringSync(),
            )
            as List;
    for (final f in fixtures) {
      final p = DeliveryEtaRouteProfile.fromJson(f['expected_profile'])!;
      final seconds = p.remainingMinutes(p.points.first) * 60;
      final duration = Duration(microseconds: (seconds * 1000000).ceil());
      expect(
        p.metersForDuration(p.points.first, duration),
        closeTo(p.distanceMeters, 1e-6),
      );
      final halfway = p.metersForDuration(
        p.points.first,
        Duration(microseconds: (seconds * 500000).floor()),
      );
      expect(halfway, greaterThan(0));
      expect(halfway, lessThan(p.distanceMeters));
    }
  });
}
