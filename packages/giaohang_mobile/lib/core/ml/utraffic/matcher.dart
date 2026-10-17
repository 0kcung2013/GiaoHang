import 'dart:math' as math;

const _cell = .001;
const _meters = 111195.0802335329;
double _radians(double value) => value * math.pi / 180;
double _hypot(double x, double y) => math.sqrt(x * x + y * y);
double distance(List<double> a, List<double> b) {
  final lat1 = _radians(a[1]), lat2 = _radians(b[1]);
  final h =
      math.pow(math.sin((lat2 - lat1) / 2), 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.pow(math.sin(_radians(b[0] - a[0]) / 2), 2);
  return 6371008.8 *
      2 *
      math.atan2(math.sqrt(h), math.sqrt(math.max(0, 1 - h)));
}

class RoadMatcher {
  RoadMatcher(Map<String, dynamic> network) {
    policy = Map<String, num>.from(network['matching_policy'] as Map);
    bounds = Map<String, num>.from(network['bounds'] as Map);
    final fields = (network['fields'] as List).cast<String>();
    for (final values in network['roads'] as List) {
      final road = {
        for (var i = 0; i < fields.length; i++)
          fields[i]: (values[i] as num).toDouble(),
      };
      road['midpoint_lat'] = (road['start_lat']! + road['end_lat']!) / 2;
      road['midpoint_lng'] = (road['start_lng']! + road['end_lng']!) / 2;
      final index = roads.length;
      roads.add(road);
      for (
        var x = (math.min(road['start_lng']!, road['end_lng']!) / _cell)
            .floor();
        x <= (math.max(road['start_lng']!, road['end_lng']!) / _cell).floor();
        x++
      ) {
        for (
          var y = (math.min(road['start_lat']!, road['end_lat']!) / _cell)
              .floor();
          y <= (math.max(road['start_lat']!, road['end_lat']!) / _cell).floor();
          y++
        ) {
          (_grid['$x,$y'] ??= []).add(index);
        }
      }
      (_nodePairs['${road['s_node_id']!.toInt()},${road['e_node_id']!.toInt()}'] ??=
              [])
          .add(index);
    }
  }
  late final Map<String, num> policy, bounds;
  final List<Map<String, double>> roads = [];
  final Map<String, List<int>> _grid = {}, _nodePairs = {};
  bool supports(List<double> p) =>
      p.length == 2 &&
      p.every((v) => v.isFinite) &&
      p[0] >= bounds['min_lng']! &&
      p[0] <= bounds['max_lng']! &&
      p[1] >= bounds['min_lat']! &&
      p[1] <= bounds['max_lat']!;

  (Map<String, double>?, String) match(
    List<double> a,
    List<double> b, [
    List<num>? nodePair,
  ]) {
    if (!supports(a) || !supports(b)) return (null, 'outside_scope');
    final midpoint = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
    final x = (midpoint[0] / _cell).floor(), y = (midpoint[1] / _cell).floor();
    final candidates = <int>{};
    for (final dx in [-1, 0, 1]) {
      for (final dy in [-1, 0, 1]) {
        candidates.addAll(_grid['${x + dx},${y + dy}'] ?? []);
      }
    }
    final exact = nodePair == null
        ? <int>{}
        : (_nodePairs['${nodePair[0].toInt()},${nodePair[1].toInt()}'] ?? [])
              .toSet();
    final scored = <(double, int)>[];
    final cosine = math.cos(_radians(midpoint[1]));
    for (final i in candidates) {
      final r = roads[i];
      final rx = (r['end_lng']! - r['start_lng']!) * cosine * _meters;
      final ry = (r['end_lat']! - r['start_lat']!) * _meters;
      final length = _hypot(rx, ry);
      final ex = (b[0] - a[0]) * cosine * _meters, ey = (b[1] - a[1]) * _meters;
      final edge = _hypot(ex, ey);
      if (length == 0 ||
          edge == 0 ||
          (rx * ex + ry * ey) / (length * edge) <
              math.cos(
                _radians(policy['maximum_heading_degrees']!.toDouble()),
              )) {
        continue;
      }
      var lateral = 0.0, accepted = true;
      for (final p in [a, midpoint, b]) {
        final px = (p[0] - r['start_lng']!) * cosine * _meters;
        final py = (p[1] - r['start_lat']!) * _meters;
        final projection = (px * rx + py * ry) / length;
        lateral = math.max(lateral, (px * ry - py * rx).abs() / length);
        if (projection < -policy['endpoint_slack_meters']! ||
            projection > length + policy['endpoint_slack_meters']!) {
          accepted = false;
        }
      }
      if (accepted && lateral <= policy['maximum_lateral_meters']!) {
        scored.add((lateral, i));
      }
    }
    if (scored.isEmpty) return (null, 'no_directed_geometry_match');
    scored.sort(
      (a, b) => a.$1 == b.$1 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1),
    );
    final exactScored = scored.where((s) => exact.contains(s.$2)).toList();
    if (exactScored.length == 1) {
      return (roads[exactScored.first.$2], 'directed_nodes_and_geometry');
    }
    if (scored.length > 1 &&
        scored[1].$1 - scored[0].$1 < policy['ambiguity_margin_meters']!) {
      return (null, 'ambiguous_parallel_or_overlapping');
    }
    return (roads[scored.first.$2], 'directed_geometry');
  }
}
