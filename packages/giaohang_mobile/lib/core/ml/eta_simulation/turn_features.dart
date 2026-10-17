import 'dart:math' as math;

class RouteTurn {
  const RouteTurn(this.at, this.strength);
  final double at, strength;
}

List<RouteTurn> routeTurns(List<List<double>> points, List<double> lengths) {
  final cumulative = <double>[0];
  for (final meters in lengths) {
    cumulative.add(cumulative.last + meters);
  }
  final candidates = <RouteTurn>[];
  for (var i = 1; i < points.length - 1; i++) {
    var before = i - 1, after = i + 1;
    while (before > 0 && cumulative[i] - cumulative[before] < 12) {
      before--;
    }
    while (after < points.length - 1 &&
        cumulative[after] - cumulative[i] < 12) {
      after++;
    }
    if (cumulative[i] - cumulative[before] < 2 ||
        cumulative[after] - cumulative[i] < 2) {
      continue;
    }
    final cos = math.cos(points[i][1] * math.pi / 180);
    double bearing(List<double> a, List<double> b) =>
        math.atan2((b[0] - a[0]) * cos, b[1] - a[1]);
    final delta =
        bearing(points[i], points[after]) - bearing(points[before], points[i]);
    final angle =
        math.atan2(math.sin(delta), math.cos(delta)).abs() * 180 / math.pi;
    if (angle < 30) continue;
    final turn = RouteTurn(cumulative[i], math.min(1, angle / 90));
    if (candidates.isNotEmpty && turn.at - candidates.last.at < 25) {
      if (turn.strength > candidates.last.strength) {
        candidates[candidates.length - 1] = turn;
      }
    } else {
      candidates.add(turn);
    }
  }
  return candidates;
}

double turnIntensity(List<RouteTurn> turns, double at) {
  var value = 0.0;
  for (final turn in turns) {
    final delta = at - turn.at;
    final zone = delta < 0 ? 55 + 15 * turn.strength : 35 + 15 * turn.strength;
    value = math.max(
      value,
      turn.strength *
          math.max(0, 1 - math.max(0, delta.abs() - 6) / (zone - 6)),
    );
  }
  return (value * 1e6).round() / 1e6;
}

List<double> turnCuts(List<RouteTurn> turns, double start, double length) {
  final values = <double>[0, 1];
  for (final turn in turns) {
    final from = turn.at - 55 - 15 * turn.strength,
        to = turn.at + 35 + 15 * turn.strength;
    if (to <= start || from >= start + length) continue;
    for (var at = from; at < to; at += 8) {
      if (at > start && at < start + length) values.add((at - start) / length);
    }
    for (final at in [turn.at - 6, turn.at, turn.at + 6, to]) {
      if (at > start && at < start + length) values.add((at - start) / length);
    }
  }
  return values;
}

/// Local road context stays stable when the destination changes.
double roadVariation(List<double> a, List<double> b) {
  final x = (a[0] + b[0]) / 2, y = (a[1] + b[1]) / 2;
  final cellX = (x / .002).floor(), cellY = (y / .002).floor();
  return ((cellX * 73856093 + cellY * 19349663) % 1009) / 1008;
}
