import 'dart:math' as math;

const etaFeatureNames = [
  'distance_km',
  'baseline_minutes',
  'base_speed_kmh',
  'direct_km',
  'detour_ratio',
  'minor_road_share',
  'junction_density',
  'signal_density',
  'turns_per_km',
  'start_lat',
  'start_lng',
  'end_lat',
  'end_lng',
  'hour',
  'hour_sin',
  'hour_cos',
  'weekday',
  'weekend',
];
const _cell = .0025;

double etaDistance(List<double> a, List<double> b) {
  const radians = math.pi / 180;
  final lat1 = a[1] * radians, lat2 = b[1] * radians;
  final h =
      math.pow(math.sin((lat2 - lat1) / 2), 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.pow(math.sin((b[0] - a[0]) * radians / 2), 2);
  return 6371008.8 *
      2 *
      math.atan2(math.sqrt(h), math.sqrt(math.max(0, 1 - h)));
}

List<double> etaContextAt(List<double> point, Map<String, dynamic> context) {
  final key = '${(point[0] / _cell).floor()},${(point[1] / _cell).floor()}';
  final cell = (context['cells'] as Map)[key] ?? context['default_cell'];
  return (cell as List).map((v) => (v as num).toDouble()).toList();
}

List<List<double>> etaPoints(Map<String, dynamic> route) {
  final raw = (route['geometry'] as Map)['coordinates'] as List;
  return raw
      .map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
      .toList();
}

Map<String, double> etaStaticFeatures(
  Map<String, dynamic> route,
  Map<String, dynamic> context,
) {
  final points = etaPoints(route);
  final meters = (route['distance'] as num).toDouble();
  final seconds = (route['duration'] as num).toDouble();
  if (points.length < 2 ||
      !meters.isFinite ||
      !seconds.isFinite ||
      meters <= 0 ||
      seconds <= 0 ||
      points.any(
        (p) =>
            p.length != 2 ||
            p.any((v) => !v.isFinite) ||
            p[0].abs() > 180 ||
            p[1].abs() > 90,
      )) {
    throw ArgumentError('INVALID_ETA_ROUTE');
  }
  final lengths = [
    for (var i = 1; i < points.length; i++)
      etaDistance(points[i - 1], points[i]),
  ];
  final total = lengths.fold(0.0, (a, b) => a + b);
  if (total <= 0) throw ArgumentError('EMPTY_ETA_GEOMETRY');
  final values = [0.0, 0.0, 0.0];
  var turns = 0;
  double? previous;
  for (var i = 0; i < lengths.length; i++) {
    final a = points[i], b = points[i + 1], length = lengths[i];
    if (length <= .1) continue;
    final dx = (b[0] - a[0]) * math.cos((a[1] + b[1]) / 2 * math.pi / 180);
    final dy = b[1] - a[1], bearing = math.atan2(dx, dy);
    if (previous != null &&
        math
                .atan2(
                  math.sin(bearing - previous),
                  math.cos(bearing - previous),
                )
                .abs() >=
            math.pi / 4) {
      turns++;
    }
    previous = bearing;
    final probes = math.max(1, (length / 100).ceil());
    for (var part = 0; part < probes; part++) {
      final p = [
        for (var j = 0; j < 2; j++) a[j] + (b[j] - a[j]) * (part + .5) / probes,
      ];
      final cell = etaContextAt(p, context);
      for (var j = 0; j < 3; j++) {
        values[j] += cell[j] * length / probes / total;
      }
    }
  }
  final first = points.first, last = points.last;
  final direct = etaDistance(first, last) / 1000;
  return {
    'distance_km': meters / 1000,
    'baseline_minutes': seconds / 60,
    'base_speed_kmh': math.min(90, meters / seconds * 3.6),
    'direct_km': direct,
    'detour_ratio': math.min(10, meters / math.max(50, direct * 1000)),
    'minor_road_share': values[0],
    'junction_density': values[1],
    'signal_density': values[2],
    'turns_per_km': math.min(30, turns / math.max(.1, meters / 1000)),
    'start_lat': first[1],
    'start_lng': first[0],
    'end_lat': last[1],
    'end_lng': last[0],
  };
}

List<double> etaTimedFeatures(Map<String, double> features, String at) {
  final wall = DateTime.parse(at).toUtc().add(const Duration(hours: 7));
  final hour = wall.hour + wall.minute / 60, weekday = wall.weekday - 1;
  final values = <String, num>{
    ...features,
    'hour': hour,
    'hour_sin': math.sin(hour * 2 * math.pi / 24),
    'hour_cos': math.cos(hour * 2 * math.pi / 24),
    'weekday': weekday,
    'weekend': weekday >= 5 ? 1 : 0,
  };
  return [
    for (final name in etaFeatureNames)
      (values[name]! * 1e6 + .5).floor() / 1e6,
  ];
}

bool etaSupports(Map<String, dynamic> route, Map<String, dynamic> metadata) {
  final bounds = metadata['bounds'] as Map, distance = route['distance'] as num;
  return distance >= (metadata['minimum_route_meters'] as num) &&
      distance <= (metadata['maximum_route_meters'] as num) &&
      etaPoints(route).every(
        (p) =>
            p[0] >= (bounds['min_lng'] as num) &&
            p[0] <= (bounds['max_lng'] as num) &&
            p[1] >= (bounds['min_lat'] as num) &&
            p[1] <= (bounds['max_lat'] as num),
      );
}
