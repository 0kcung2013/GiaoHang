/// Crossroads are intrinsic to the road network, independent of the chosen turn.
List<List<double>> extractRouteJunctions(Map<String, dynamic> raw) {
  final points = <String, List<double>>{};
  void add(dynamic p) {
    if (p is! List || p.length != 2 || p.any((v) => v is! num || !v.isFinite)) {
      return;
    }
    final point = p.map((v) => (v as num).toDouble()).toList();
    if (point[0].abs() > 180 || point[1].abs() > 90) return;
    points['${point[0]},${point[1]}'] = point;
  }

  for (final p in raw['junction_points'] as List? ?? const []) {
    add(p);
  }
  for (final leg in raw['legs'] as List? ?? const []) {
    for (final step in (leg as Map)['steps'] as List? ?? const []) {
      for (final intersection
          in (step as Map)['intersections'] as List? ?? const []) {
        if (((intersection as Map)['bearings'] as List? ?? const []).length >=
            3) {
          add(intersection['location']);
        }
      }
    }
  }
  return points.values.toList();
}
