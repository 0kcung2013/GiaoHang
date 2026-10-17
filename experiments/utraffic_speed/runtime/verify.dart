import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../../../packages/giaohang_mobile/lib/core/ml/utraffic/model.dart';
import '../../../packages/giaohang_mobile/lib/core/ml/utraffic/matcher.dart';
import '../../../packages/giaohang_mobile/lib/core/ml/utraffic/profile.dart';

void check(bool passed, String reason) {
  if (!passed) throw StateError(reason);
}

void main(List<String> args) {
  final dir = args.isEmpty ? 'output/utraffic_speed/runtime' : args.first;
  dynamic read(String name) =>
      jsonDecode(File('$dir/$name.json').readAsStringSync());
  final watch = Stopwatch()..start();
  final model = SpeedModel(read('model') as Map<String, dynamic>);
  final matcher = RoadMatcher(read('network') as Map<String, dynamic>);
  final load = watch.elapsedMicroseconds / 1000;
  var speedError = 0.0, featureError = 0.0, routeError = 0.0;
  final cases = read('parity') as List;
  for (final c in cases) {
    final vector = model.featuresAt(
      Map<String, num>.from(c['road'] as Map),
      c['at'] as String,
    );
    final expected = (c['features'] as List).cast<num>();
    for (var i = 0; i < vector.length; i++) {
      featureError = math.max(featureError, (vector[i] - expected[i]).abs());
    }
    speedError = math.max(
      speedError,
      (model.predict(vector) - (c['speed_kmh'] as num)).abs(),
    );
  }
  check(featureError < 1e-10, 'FEATURE_PARITY');
  check(speedError < 1e-8, 'SPEED_PARITY');
  final routes = read('route_parity') as List;
  final timings = <Map<String, dynamic>>[];
  for (final fixture in routes) {
    final started = watch.elapsedMicroseconds;
    final actual = buildRouteSpeedProfile(
      fixture['route'] as Map<String, dynamic>,
      fixture['at'] as String,
      model,
      matcher,
    );
    final expected = fixture['expected'] as Map;
    final sections = actual['speed_profile'] as List;
    timings.add({
      'name': fixture['name'],
      'milliseconds': (watch.elapsedMicroseconds - started) / 1000,
      'sections': sections.length,
      'payload_bytes': utf8.encode(jsonEncode(actual)).length,
    });
    check(
      sections.length == (expected['speed_profile'] as List).length,
      'SECTION_COUNT',
    );
    routeError = math.max(
      routeError,
      ((actual['travel_minutes'] as num) - (expected['travel_minutes'] as num))
          .abs()
          .toDouble(),
    );
    check(
      ((actual['ai_coverage_ratio'] as num) -
                  (expected['ai_coverage_ratio'] as num))
              .abs() <
          1e-10,
      'COVERAGE_PARITY',
    );
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i] as Map,
          e = (expected['speed_profile'] as List)[i] as Map;
      check(
        s['segment_id'] == e['segment_id'] &&
            s['used_ai'] == e['used_ai'] &&
            s['match_method'] == e['match_method'],
        'MATCH_PARITY',
      );
      check(
        ((s['speed_kmh'] as num) - (e['speed_kmh'] as num)).abs() < 1e-8,
        'PROFILE_SPEED',
      );
      check(
        ((s['start_meters'] as num) - (e['start_meters'] as num)).abs() < 1e-6,
        'PROFILE_DISTANCE',
      );
      check(
        ((s['end_meters'] as num) - (e['end_meters'] as num)).abs() < 1e-6,
        'PROFILE_END_DISTANCE',
      );
      check(
        (DateTime.parse(s['forecast_at'] as String).millisecondsSinceEpoch -
                    DateTime.parse(
                      e['forecast_at'] as String,
                    ).millisecondsSinceEpoch)
                .abs() <=
            1,
        'PROFILE_CLOCK',
      );
    }
  }
  check(routeError < 1e-6, 'ROUTE_DURATION_PARITY');
  final result = {
    'language': 'Dart',
    'speed_cases': cases.length,
    'route_cases': routes.length,
    'maximum_speed_error': speedError,
    'maximum_feature_error': featureError,
    'maximum_route_minutes_error': routeError,
    'cold_load_milliseconds': load,
    'route_timings': timings,
  };
  File(
    '$dir/dart_verification.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(jsonEncode(result));
}
