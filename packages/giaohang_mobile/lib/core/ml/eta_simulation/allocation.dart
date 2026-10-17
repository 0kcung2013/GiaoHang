import 'dart:convert';
import 'dart:math' as math;
import 'features.dart';

double _clamp(double v, double low, double high) =>
    v.clamp(low, high).toDouble();
final _decoded = Expando<Map<String, List<_Junction>>>('eta_junction_cells');

class _Junction {
  _Junction(this.id, this.point);
  final String id;
  final List<double> point;
}

List<_Junction> _junctions(List<double> point, Map<String, dynamic> context) {
  final cache = _decoded[context] ??= <String, List<_Junction>>{};
  final scale = (context['junction_coordinate_scale'] as num? ?? 100000)
      .toDouble();
  final ticks = (context['junction_cell_ticks'] as num? ?? 250).toInt();
  final cx = (point[0] * scale / ticks).floor(),
      cy = (point[1] * scale / ticks).floor();
  final encodedCells = context['junction_cells'] as Map?;
  final result = <_Junction>[];
  for (var x = cx - 1; x <= cx + 1; x++) {
    for (var y = cy - 1; y <= cy + 1; y++) {
      final key = '$x,$y';
      final points = cache.putIfAbsent(key, () {
        final encoded = encodedCells?[key] as String?;
        if (encoded == null) return <_Junction>[];
        final bytes = base64Decode(encoded), points = <_Junction>[];
        for (var i = 0; i + 1 < bytes.length; i += 2) {
          points.add(
            _Junction('$key:$i', [
              (x * ticks + bytes[i]) / scale,
              (y * ticks + bytes[i + 1]) / scale,
            ]),
          );
        }
        return points;
      });
      result.addAll(points);
    }
  }
  return result;
}

class _Candidate {
  _Candidate(this.at, this.source, this.priority, this.error);
  final double at, error;
  final String source;
  final int priority;
}

List<Map<String, dynamic>> _stopZones(
  Map<String, dynamic> route,
  Map<String, dynamic> context,
  List<double> lengths,
  double totalGeometry,
) {
  final points = etaPoints(route),
      total = (route['distance'] as num).toDouble();
  final candidates = <String, _Candidate>{}, ratio = total / totalGeometry;
  var along = 0.0;
  double? previous;
  for (var i = 0; i < lengths.length; i++) {
    final a = points[i], b = points[i + 1], length = lengths[i];
    if (length <= .1) continue;
    final cosine = math.cos((a[1] + b[1]) / 2 * math.pi / 180),
        dx = (b[0] - a[0]) * cosine,
        dy = b[1] - a[1];
    final denominator = dx * dx + dy * dy, bearing = math.atan2(dx, dy);
    if (previous != null &&
        math
                .atan2(
                  math.sin(bearing - previous),
                  math.cos(bearing - previous),
                )
                .abs() >=
            math.pi / 4) {
      candidates['turn:$i'] = _Candidate(along * ratio, 'route_turn', 2, 0);
    }
    previous = bearing;
    final probes = math.max(1, (length / 100).ceil()), seen = <String>{};
    for (var probe = 0; probe < probes; probe++) {
      final midpoint = [
        for (var k = 0; k < 2; k++)
          a[k] + (b[k] - a[k]) * (probe + .5) / probes,
      ];
      for (final junction in _junctions(midpoint, context)) {
        if (!seen.add(junction.id)) continue;
        final p = junction.point, px = (p[0] - a[0]) * cosine, py = p[1] - a[1];
        final t = _clamp((px * dx + py * dy) / denominator, 0, 1);
        final ex = px - dx * t, ey = py - dy * t;
        final error = math.sqrt(ex * ex + ey * ey) * 111195;
        if (error > 8) continue;
        final at = (along + t * length) * ratio,
            key = '${junction.id}:${(at / 80).floor()}';
        final existing = candidates[key];
        if (existing == null || error < existing.error) {
          candidates[key] = _Candidate(at, 'osm_junction', 1, error);
        }
      }
    }
    along += length;
  }
  final ordered =
      candidates.values.where((c) => c.at >= 20 && c.at <= total - 20).toList()
        ..sort((a, b) {
          final priority = b.priority.compareTo(a.priority);
          if (priority != 0) return priority;
          final position = a.at.compareTo(b.at);
          return position != 0 ? position : a.error.compareTo(b.error);
        });
  final accepted = <_Candidate>[];
  for (final candidate in ordered) {
    if (accepted.any((c) => (c.at - candidate.at).abs() < 80)) continue;
    accepted.add(candidate);
  }
  accepted.sort((a, b) => a.at.compareTo(b.at));
  return [
    for (final c in accepted)
      {
        'at_meters': c.at,
        'start_meters': math.max(0.0, c.at - 25),
        'end_meters': math.min(total, c.at + 25),
        'source': c.source,
        'weight': c.priority,
      },
  ];
}

class EtaAllocationPart {
  EtaAllocationPart(
    this.from,
    this.to,
    this.meters,
    this.baseline,
    this.cruise,
    this.stopWeight,
    this.zone,
  );
  final double from, baseline, cruise, stopWeight;
  final int zone;
  double to, meters, referenceSpeed = 0;
}

class EtaTravelAllocation {
  EtaTravelAllocation(this.parts, this.zones);
  final List<EtaAllocationPart> parts;
  final List<Map<String, dynamic>> zones;
}

EtaTravelAllocation buildTravelAllocation(
  Map<String, dynamic> route,
  Map<String, dynamic> context,
  String at,
) {
  final points = etaPoints(route);
  final lengths = [
    for (var i = 1; i < points.length; i++)
      etaDistance(points[i - 1], points[i]),
  ];
  final totalGeometry = lengths.fold(0.0, (a, b) => a + b);
  if (totalGeometry <= 0) throw ArgumentError('EMPTY_ETA_ALLOCATION');
  final legs = route['legs'] as List;
  final annotation = legs.isEmpty
      ? null
      : (legs.first as Map)['annotation'] as Map?;
  final durations = annotation?['duration'] as List?;
  final annotated =
      durations != null &&
      durations.length == lengths.length &&
      durations.every((v) => v is num && v.isFinite && v >= 0);
  final wall = DateTime.parse(at).toUtc().add(const Duration(hours: 7));
  final hour = wall.hour + wall.minute / 60, weekday = wall.weekday - 1;
  final peak =
      math.max(
        math.exp(-.5 * math.pow((hour - 7.8) / 1.05, 2)),
        math.exp(-.5 * math.pow((hour - 17.5) / 1.25, 2)),
      ) *
      (weekday >= 5 ? .48 : 1);
  final total = (route['distance'] as num).toDouble(),
      seconds = (route['duration'] as num).toDouble();
  final zones = _stopZones(route, context, lengths, totalGeometry);
  final cuts = [
    for (final z in zones) ...[
      (z['start_meters'] as num).toDouble(),
      (z['at_meters'] as num).toDouble(),
      (z['end_meters'] as num).toDouble(),
    ],
  ];
  final parts = <EtaAllocationPart>[];
  var along = 0.0, baselineSum = 0.0;
  for (var i = 0; i < lengths.length; i++) {
    final a = points[i], b = points[i + 1], length = lengths[i];
    if (length <= .1) continue;
    final count = math.max(1, (length / 100).ceil());
    for (var j = 0; j < count; j++) {
      final midpoint = [
        for (var k = 0; k < 2; k++) a[k] + (b[k] - a[k]) * (j + .5) / count,
      ];
      final cell = etaContextAt(midpoint, context),
          meters = length / count * total / totalGeometry;
      final baseline = annotated && (durations[i] as num) > 0
          ? (durations[i] as num).toDouble() / count
          : seconds * length / count / totalGeometry * (.9 + .3 * cell[0]);
      final from = along, to = along + meters;
      final boundaries = [
        from,
        ...cuts.where((c) => c > from + 1e-7 && c < to - 1e-7),
        to,
      ]..sort();
      for (var k = 1; k < boundaries.length; k++) {
        final start = boundaries[k - 1],
            end = boundaries[k],
            center = (start + end) / 2;
        final zone = zones.indexWhere(
          (z) =>
              center >= (z['start_meters'] as num) &&
              center <= (z['end_meters'] as num),
        );
        final stopWeight = zone >= 0
            ? math.max(
                    0.0,
                    1 - (center - (zones[zone]['at_meters'] as num)).abs() / 25,
                  ) *
                  (zones[zone]['weight'] as num)
            : 0.0;
        final base = baseline * (end - start) / meters;
        parts.add(
          EtaAllocationPart(
            start,
            end,
            end - start,
            base,
            .98 + .10 * cell[0] + peak * (.35 + .35 * cell[0]),
            stopWeight.toDouble(),
            zone,
          ),
        );
        baselineSum += base;
      }
      along = to;
    }
  }
  if (parts.isEmpty || baselineSum <= 0) {
    throw ArgumentError('EMPTY_ETA_ALLOCATION');
  }
  parts.last.to = total;
  parts.last.meters = parts.last.to - parts.last.from;
  for (final p in parts) {
    p.referenceSpeed = _clamp(
      p.meters * 3.6 / (p.baseline * seconds / baselineSum),
      1,
      90,
    );
  }
  return EtaTravelAllocation(parts, zones);
}

class EtaAllocationFit {
  EtaAllocationFit(
    this.speeds,
    this.localized,
    this.movingSeconds,
    this.waitingSeconds,
  );
  final List<double> speeds;
  final bool localized;
  final double movingSeconds, waitingSeconds;
}

EtaAllocationFit fitTravelAllocation(
  EtaTravelAllocation allocation,
  double seconds,
) {
  final parts = allocation.parts;
  double speed(EtaAllocationPart p, double cruiseScale, double waitScale) =>
      _clamp(
        p.referenceSpeed / (p.cruise * cruiseScale + p.stopWeight * waitScale),
        1,
        90,
      );
  double duration(double cruiseScale, double waitScale) => parts.fold(
    0.0,
    (sum, p) => sum + p.meters * 3.6 / speed(p, cruiseScale, waitScale),
  );
  var cruiseScale = 1.0, waitScale = 0.0, localized = true;
  if (seconds < duration(1, 0)) {
    var low = .001, high = 1.0;
    for (var i = 0; i < 60; i++) {
      final mid = (low + high) / 2;
      if (duration(mid, 0) < seconds) {
        low = mid;
      } else {
        high = mid;
      }
    }
    cruiseScale = (low + high) / 2;
  } else if (seconds > duration(1, 0) + 1e-7) {
    var high = 1.0;
    while (high < 1048576 && duration(1, high) < seconds) {
      high *= 2;
    }
    if (allocation.zones.isNotEmpty && duration(1, high) >= seconds) {
      var low = 0.0;
      for (var i = 0; i < 60; i++) {
        final mid = (low + high) / 2;
        if (duration(1, mid) < seconds) {
          low = mid;
        } else {
          high = mid;
        }
      }
      waitScale = (low + high) / 2;
    } else {
      localized = false;
      var low = .001;
      high = 1048576;
      for (var i = 0; i < 60; i++) {
        final mid = (low + high) / 2;
        if (duration(mid, 0) < seconds) {
          low = mid;
        } else {
          high = mid;
        }
      }
      cruiseScale = (low + high) / 2;
    }
  }
  final speeds = [for (final p in parts) speed(p, cruiseScale, waitScale)];
  final moving = parts.fold(
    0.0,
    (sum, p) => sum + p.meters * 3.6 / speed(p, cruiseScale, 0),
  );
  var actual = 0.0;
  for (var i = 0; i < parts.length; i++) {
    actual += parts[i].meters * 3.6 / speeds[i];
  }
  return EtaAllocationFit(
    speeds,
    localized,
    moving,
    math.max(0.0, actual - moving),
  );
}
