import 'features.dart';
import 'coverage.dart';
import '../../constants/eta_simulation_strings.dart';
import 'segment_speeds.dart';
import 'model.dart';
import '../../utils/osrm_route_junctions.dart';

Map<String, dynamic> buildEtaRoutingFallback(
  Map<String, dynamic> route,
  DateTime at,
  Map<String, dynamic> metadata, {
  required String reason,
}) {
  final seconds = (route['duration'] as num).toDouble(),
      meters = (route['distance'] as num).toDouble();
  return {
    'distance_meters': meters,
    'route_points': (route['geometry'] as Map)['coordinates'],
    'forecast_at': at.toIso8601String(),
    'travel_minutes': seconds / 60,
    'baseline_seconds': seconds,
    'osrm_seconds': seconds,
    'used_ai': false,
    'all_sections_ai': false,
    'ai_coverage_ratio': 0,
    'ai_distance_meters': 0,
    'is_synthetic': false,
    'coverage_version': EtaSimulationCoverage.version,
    'fallback_reason': reason,
    'profile_version': 6,
    'model_version': metadata['version'],
    'dataset_label': metadata['dataset_label'],
    'dataset_scope': metadata['dataset_scope'],
    'speed_profile': [
      {
        'start_meters': 0.0,
        'end_meters': meters,
        'speed_kmh': meters * 3.6 / seconds,
        'used_ai': false,
        'traffic_available': false,
        'source': 'routing_baseline',
      },
    ],
  };
}

Map<String, dynamic> normalizeEtaRoute(Map<String, dynamic> raw) {
  final meters = ((raw['distance'] ?? raw['distance_meters']) as num)
      .toDouble();
  final given = ((raw['duration'] ?? raw['osrm_seconds']) as num?)?.toDouble();
  final valid =
      given != null &&
      given.isFinite &&
      given > 0 &&
      meters / given * 3.6 >= 1 &&
      meters / given * 3.6 <= 90;
  return {
    'distance': meters,
    'duration': valid ? given : meters * .144,
    'valid_baseline': valid,
    'geometry': raw['geometry'] ?? {'coordinates': raw['points']},
    'junction_points': extractRouteJunctions(raw),
    'legs':
        raw['legs'] ??
        [
          {
            'annotation': {
              'nodes': raw['annotation_nodes'] ?? [],
              'distance': raw['annotation_distances'] ?? [],
              'duration': raw['annotation_durations'] ?? [],
            },
          },
        ],
  };
}

Map<String, dynamic> buildEtaProfile(
  Map<String, dynamic> raw,
  String at,
  EtaCorrectionModel model,
  Map<String, dynamic> context,
) {
  final route = normalizeEtaRoute(raw), start = DateTime.parse(at).toUtc();
  final total = (route['distance'] as num).toDouble();
  final points = etaPoints(route);
  if (!total.isFinite ||
      total < 0 ||
      points.length < 2 ||
      points.any(
        (p) =>
            p.length != 2 ||
            p.any((v) => !v.isFinite) ||
            p[0].abs() > 180 ||
            p[1].abs() > 90,
      )) {
    throw ArgumentError('INVALID_ETA_ROUTE');
  }
  if (total == 0) {
    return {
      'distance_meters': 0,
      'route_points': (route['geometry'] as Map)['coordinates'],
      'speed_profile': [],
      'travel_minutes': 0,
      'used_ai': false,
      'all_sections_ai': false,
      'forecast_at': start.toIso8601String(),
    };
  }
  if (!supportsSpeedSimulation(route)) {
    return buildEtaRoutingFallback(
      route,
      start,
      model.metadata,
      reason: EtaSimulationCoverage.outsideReason,
    );
  }
  final sections = buildSegmentSpeeds(route, context, at, model);
  final minutes = sections.fold(
    0.0,
    (sum, s) =>
        sum +
        ((s['end_meters'] as num) - (s['start_meters'] as num)) *
            .06 /
            (s['speed_kmh'] as num),
  );
  return {
    'distance_meters': total,
    'route_points': (route['geometry'] as Map)['coordinates'],
    'forecast_at': start.toIso8601String(),
    'speed_profile': sections,
    'travel_minutes': minutes,
    'baseline_seconds': route['duration'],
    'osrm_seconds': route['duration'],
    'used_ai': true,
    'coverage_version': EtaSimulationCoverage.version,
    'all_sections_ai': true,
    'ai_distance_meters': total,
    'ai_coverage_ratio': 1,
    'color_metric': 'speed_kmh',
    'model_version': model.metadata['version'],
    'is_synthetic': true,
    'dataset_label': EtaSimulationStrings.datasetLabel,
    'dataset_scope': EtaSimulationStrings.datasetScope,
    'profile_version': 6,
    'speed_model_version': segmentSpeedVersion,
    'profile_source': segmentSpeedVersion,
    'uses_realtime_traffic': false,
  };
}
