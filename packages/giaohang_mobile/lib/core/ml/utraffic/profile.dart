import 'dart:math' as math;
import 'matcher.dart';
import 'model.dart';

void _appendSection(
  List<Map<String, dynamic>> sections,
  Map<String, dynamic> section,
) {
  const keys = [
    'speed_kmh',
    'used_ai',
    'segment_id',
    'match_method',
    'training_count',
  ];
  if (sections.isNotEmpty &&
      keys.every((key) => sections.last[key] == section[key])) {
    sections.last['end_meters'] = section['end_meters'];
    sections.last['travel_minutes'] =
        (sections.last['travel_minutes'] as double) +
        (section['travel_minutes'] as double);
  } else {
    sections.add(section);
  }
}

Map<String, dynamic> buildRouteSpeedProfile(
  Map<String, dynamic> route,
  String at,
  SpeedModel? model,
  RoadMatcher matcher, {
  double fallbackSpeed = 25,
}) {
  final points = ((route['geometry'] as Map)['coordinates'] as List)
      .map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
      .toList();
  final total = (route['distance'] as num).toDouble();
  final start = DateTime.parse(at).toUtc();
  if (!total.isFinite ||
      total <= 0 ||
      points.length < 2 ||
      !fallbackSpeed.isFinite ||
      fallbackSpeed <= 0 ||
      fallbackSpeed > 90 ||
      points.any(
        (p) =>
            p.length != 2 ||
            p.any((v) => !v.isFinite) ||
            p[0].abs() > 180 ||
            p[1].abs() > 90,
      )) {
    throw ArgumentError('INVALID_ROUTE_PROFILE');
  }
  final lengths = [
    for (var i = 1; i < points.length; i++) distance(points[i - 1], points[i]),
  ];
  final geometryLength = lengths.fold(0.0, (a, b) => a + b);
  if (geometryLength <= 0) throw ArgumentError('EMPTY_ROUTE_GEOMETRY');
  final legs = (route['legs'] as List?) ?? [];
  final annotation = legs.isEmpty
      ? null
      : (legs.first as Map)['annotation'] as Map?;
  final nodes = (annotation?['nodes'] as List?) ?? [];
  final aligned = nodes.length == points.length;
  var along = 0.0, minutes = 0.0, aiDistance = 0.0;
  final sections = <Map<String, dynamic>>[];
  for (var i = 0; i < lengths.length; i++) {
    final a = points[i], b = points[i + 1], length = lengths[i];
    if (length <= 0) continue;
    final count = math.max(
      1,
      (length / matcher.policy['probe_meters']!).ceil(),
    );
    for (var part = 0; part < count; part++) {
      final first = [
        for (var j = 0; j < 2; j++) a[j] + (b[j] - a[j]) * part / count,
      ];
      final second = [
        for (var j = 0; j < 2; j++) a[j] + (b[j] - a[j]) * (part + 1) / count,
      ];
      final (road, matchedMethod) = matcher.match(
        first,
        second,
        aligned ? [nodes[i] as num, nodes[i + 1] as num] : null,
      );
      var method = matchedMethod;
      final forecast = start
          .add(Duration(milliseconds: (minutes * 60000).truncate()))
          .toIso8601String();
      double? predicted;
      if (road != null && total <= 25000 && model != null) {
        try {
          predicted = model.speedAt(road, forecast);
        } catch (_) {
          /* Per-section fallback. */
        }
      }
      final usedAi =
          predicted != null &&
          predicted.isFinite &&
          predicted > 0 &&
          predicted <= 90;
      if (road != null && !usedAi) {
        method = total > 25000
            ? 'distance_outside_scope'
            : 'model_unavailable_or_invalid';
      }
      final speed = usedAi ? predicted : fallbackSpeed;
      final from = along;
      along += length / count * total / geometryLength;
      final travel = (along - from) * .06 / speed;
      _appendSection(sections, {
        'start_meters': from,
        'end_meters': along,
        'speed_kmh': speed,
        'used_ai': usedAi,
        'forecast_at': forecast,
        'travel_minutes': travel,
        'segment_id': road?['segment_id']?.toInt(),
        'source': usedAi ? 'utraffic_lightgbm' : 'fallback_25_kmh',
        'match_method': method,
        'training_count': road?['training_count']?.toInt() ?? 0,
      });
      minutes += travel;
      if (usedAi) aiDistance += along - from;
    }
  }
  final last = sections.last;
  final correction = total - (last['end_meters'] as double);
  final adjustment = correction * .06 / (last['speed_kmh'] as double);
  minutes += adjustment;
  last['travel_minutes'] = (last['travel_minutes'] as double) + adjustment;
  last['end_meters'] = total;
  if (last['used_ai'] as bool) aiDistance += correction;
  return {
    'distance_meters': total,
    'route_points': points,
    'forecast_at': start.toIso8601String(),
    'speed_profile': sections,
    'travel_minutes': minutes,
    'used_ai': aiDistance > 0,
    'all_sections_ai': sections.every((s) => s['used_ai'] as bool),
    'ai_distance_meters': aiDistance,
    'ai_coverage_ratio': aiDistance / total,
    'model_version': model?.metadata['version'],
  };
}
