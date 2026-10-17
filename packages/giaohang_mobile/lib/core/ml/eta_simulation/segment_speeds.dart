import 'dart:math' as math;
import 'features.dart';
import 'coverage.dart';
import 'model.dart';
import 'speed_features.dart';
import 'turn_features.dart';

const segmentSpeedVersion = 'hcm_synthetic_segment_speed_v2';
const _cellDegrees = .001;
bool supportsSpeedSimulation(Map<String, dynamic> route) =>
    EtaSimulationCoverage.containsRoute(etaPoints(route));
List<double> _gridCuts(List<double> a, List<double> b) {
  final cuts = <double>[0, 1];
  for (var axis = 0; axis < 2; axis++) {
    final delta = b[axis] - a[axis];
    if (delta.abs() < 1e-12) continue;
    for (
      var n = (math.min(a[axis], b[axis]) / _cellDegrees).floor() + 1;
      n * _cellDegrees < math.max(a[axis], b[axis]);
      n++
    ) {
      final t = (n * _cellDegrees - a[axis]) / delta;
      if (t > 1e-9 && t < 1 - 1e-9) cuts.add(t);
    }
  }
  cuts.sort();
  return [
    for (var i = 0; i < cuts.length; i++)
      if (i == 0 || cuts[i] - cuts[i - 1] > 1e-9) cuts[i],
  ];
}

List<Map<String, dynamic>> buildSegmentSpeeds(
  Map<String, dynamic> route,
  Map<String, dynamic> context,
  String at,
  EtaCorrectionModel model,
) {
  if (model.metadata['target'] != 'segment_speed_kmh') {
    throw ArgumentError('INVALID_SPEED_MODEL_TARGET');
  }
  final points = etaPoints(route);
  final lengths = [
    for (var i = 1; i < points.length; i++)
      etaDistance(points[i - 1], points[i]),
  ];
  final geometry = lengths.fold(0.0, (a, b) => a + b);
  final turns = routeTurns(points, lengths);
  var geometryAlong = 0.0;
  if (geometry <= 0) throw ArgumentError('EMPTY_ETA_GEOMETRY');
  final scale = (route['distance'] as num) / geometry,
      index = roadIndex(context),
      clock = trafficClock(at);
  final annotation =
      ((route['legs'] as List?)?.firstOrNull as Map?)?['annotation'] as Map?;
  final nodes = annotation?['nodes'] as List?,
      distances = annotation?['distance'] as List?,
      durations = annotation?['duration'] as List?;
  final alignedNodes = nodes?.length == points.length;
  final aligned =
      distances?.length == lengths.length &&
      durations?.length == lengths.length;
  final sections = <Map<String, dynamic>>[], predictions = <String, double>{};
  var along = 0.0;
  for (var i = 0; i < lengths.length; i++) {
    final a = points[i], b = points[i + 1], length = lengths[i];
    if (length <= 0) continue;
    final first = alignedNodes ? index.get(nodes![i] as num?) : null;
    final second = alignedNodes ? index.get(nodes![i + 1] as num?) : null;
    final d = aligned ? distances![i] : null,
        seconds = aligned ? durations![i] : null;
    final raw =
        d is num &&
            seconds is num &&
            d.isFinite &&
            seconds.isFinite &&
            d > 0 &&
            seconds > 0
        ? d * 3.6 / seconds
        : null;
    final candidates = [
      ..._gridCuts(a, b),
      ...turnCuts(turns, geometryAlong, length),
    ]..sort();
    final cuts = [
      for (var k = 0; k < candidates.length; k++)
        if (k == 0 || candidates[k] - candidates[k - 1] > 1e-9) candidates[k],
    ];
    for (var j = 1; j < cuts.length; j++) {
      final t = (cuts[j - 1] + cuts[j]) / 2;
      final x = ((a[0] + (b[0] - a[0]) * t) / _cellDegrees).floor(),
          y = ((a[1] + (b[1] - a[1]) * t) / _cellDegrees).floor();
      final minor = etaContextAt([
        (x + .5) * _cellDegrees,
        (y + .5) * _cellDegrees,
      ], context)[0];
      final fallbackClass = raw != null
          ? (raw < 20
                ? 0
                : raw < 35
                ? 1
                : 2)
          : minor >= .8
          ? 0
          : minor >= .45
          ? 1
          : 2;
      final middle = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
      final vector = [
        ...roadFeatures(first, second, fallbackClass, clock),
        roadVariation(middle, middle),
        turnIntensity(turns, geometryAlong + length * t),
      ];
      final key = vector.map((v) => v.toStringAsFixed(6)).join(':');
      final speed = predictions.putIfAbsent(
        key,
        () => (model.predict(vector).clamp(15, 50) * 10).round() / 10,
      );
      final meters = length * (cuts[j] - cuts[j - 1]) * scale;
      final end = along + meters, travel = meters * .06 / speed;
      if (sections.isNotEmpty && sections.last['segment_id'] == key) {
        sections.last['end_meters'] = end;
        sections.last['travel_minutes'] =
            (sections.last['travel_minutes'] as double) + travel;
      } else {
        sections.add({
          'start_meters': along,
          'end_meters': end,
          'speed_kmh': speed,
          'reference_speed_kmh': [23.0, 37.5, 48.0][vector[0].toInt()],
          'travel_minutes': travel,
          'used_ai': true,
          'traffic_available': true,
          'is_synthetic': true,
          'segment_id': key,
          'source': segmentSpeedVersion,
          'features': vector,
          'road_class': vector[0].toInt(),
          'feature_source': first != null || second != null
              ? 'osm_nodes'
              : raw != null
              ? 'osrm_road_class'
              : 'spatial_road_class',
          'forecast_at': DateTime.parse(at).toUtc().toIso8601String(),
        });
      }
      along = end;
    }
    geometryAlong += length;
  }
  sections.last['end_meters'] = (route['distance'] as num).toDouble();
  return sections;
}
