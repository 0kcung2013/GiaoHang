import 'dart:convert';
import 'dart:math' as math;

final _cache = Expando<Map<String, List<List<double>>>>('speed_junction_cells');
const _cell = .0025, _meters = 111195.0802335329;

class JunctionSpeedField {
  JunctionSpeedField(this.context, List<List<double>> points) {
    // Global OSM coverage is independent of the route's chosen endpoints.
    for (final p
        in context['junction_bounds'] != null ? <List<double>>[] : points) {
      final key = '${(p[0] / _cell).floor()},${(p[1] / _cell).floor()}';
      (_extra[key] ??= []).add(p);
    }
  }
  final Map<String, dynamic> context;
  final _extra = <String, List<List<double>>>{};
  double slowdown(List<double> point) {
    final decoded = _cache[context] ??= <String, List<List<double>>>{};
    final scale = (context['junction_coordinate_scale'] as num? ?? 100000)
        .toDouble();
    final ticks = (context['junction_cell_ticks'] as num? ?? 250).toInt();
    final x = (point[0] * scale / ticks).floor(),
        y = (point[1] * scale / ticks).floor();
    var nearest = double.infinity;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final cx = x + dx, cy = y + dy, key = '$cx,$cy';
        final values = decoded.putIfAbsent(key, () {
          final encoded = (context['junction_cells'] as Map?)?[key] as String?;
          if (encoded == null) return <List<double>>[];
          final bytes = base64Decode(encoded);
          return [
            for (var i = 0; i + 1 < bytes.length; i += 2)
              [
                (cx * ticks + bytes[i]) / scale,
                (cy * ticks + bytes[i + 1]) / scale,
              ],
          ];
        });
        for (final p in [...values, ...?_extra[key]]) {
          final ax = (p[0] - point[0]) * math.cos(point[1] * math.pi / 180),
              ay = p[1] - point[1];
          nearest = math.min(nearest, math.sqrt(ax * ax + ay * ay) * _meters);
        }
      }
    }
    return nearest <= 18
        ? .6
        : nearest <= 36
        ? .32
        : 0;
  }
}
