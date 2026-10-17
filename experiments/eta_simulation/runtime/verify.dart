import 'dart:convert';
import 'dart:io';
import '../../../packages/giaohang_mobile/lib/core/ml/eta_simulation/features.dart';
import '../../../packages/giaohang_mobile/lib/core/ml/eta_simulation/model.dart';
import '../../../packages/giaohang_mobile/lib/core/ml/eta_simulation/profile.dart';

dynamic read(String name) => jsonDecode(File('output/eta_simulation/$name.json').readAsStringSync());
void main() {
  final started = Stopwatch()..start();
  final model = EtaCorrectionModel(Map<String, dynamic>.from(read('model')));
  final context = Map<String, dynamic>.from(read('context'));
  final loadMs = started.elapsedMicroseconds / 1000;
  var modelError = 0.0, featureError = 0.0, durationError = 0.0;
  for (final fixture in read('parity_vectors') as List) {
    final vector = (fixture['features'] as List).map((v) => (v as num).toDouble()).toList();
    final error = (model.predict(vector) - (fixture['expected_ratio'] as num)).abs();
    if (error > modelError) modelError = error;
  }
  final timings = <double>[];
  final fixtures = read('parity_profiles') as List;
  for (final fixture in fixtures) {
    final route = Map<String, dynamic>.from(fixture['route']), at = fixture['at'] as String;
    final vector = etaTimedFeatures(etaStaticFeatures(route, context), at);
    for (var i = 0; i < vector.length; i++) {
      final error = (vector[i] - (fixture['features'][i] as num)).abs();
      if (error > featureError) featureError = error;
    }
    final tick = Stopwatch()..start(), profile = buildEtaProfile(route, at, model, context);
    timings.add(tick.elapsedMicroseconds / 1000);
    final error = ((profile['lightgbm_travel_minutes'] as num) * 60 - (fixture['expected_model_seconds'] as num)).abs().toDouble();
    if (error > durationError) durationError = error;
    final sections = profile['speed_profile'] as List, expected = fixture['expected_profile']['speed_profile'] as List;
    if (profile['profile_version'] != 4 || profile['profile_source'] != fixture['expected_profile']['profile_source']) throw StateError('ALLOCATION_METADATA_MISMATCH');
    if (profile['used_ai'] != false || sections.length != expected.length) throw StateError('PROFILE_SECTION_MISMATCH');
    for (var i = 0; i < sections.length; i++) {
      if (sections[i]['used_ai'] != expected[i]['used_ai']) throw StateError('SECTION_COVERAGE_MISMATCH');
      for (final key in ['start_meters', 'end_meters', 'speed_kmh', 'reference_speed_kmh', 'travel_minutes']) {
        if (((sections[i][key] as num) - (expected[i][key] as num)).abs() > 1e-6) throw StateError('PROFILE_VALUE_MISMATCH_$key');
      }
    }
  }
  if (modelError > 1e-8 || featureError > 1e-8 || durationError > 1e-6) throw StateError('MODEL_PARITY_FAILED');
  timings.sort();
  final result = {'language': 'Dart', 'model_cases': 1000, 'route_cases': fixtures.length,
    'maximum_model_error': modelError, 'maximum_feature_error': featureError,
    'maximum_duration_error_seconds': durationError, 'cold_load_ms': loadMs,
    'warm_route_p50_ms': timings[(timings.length * .5).floor()], 'warm_route_p90_ms': timings[(timings.length * .9).floor()]};
  File('output/eta_simulation/dart_verification.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  print(const JsonEncoder.withIndent('  ').convert(result));
}
