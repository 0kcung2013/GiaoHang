import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/utils/delivery_traffic_route_analyzer.dart';
import '../../../../../core/widgets/delivery_traffic_map_layer.dart';

/// Renders the selected OSRM route in historical UTraffic colors.
///
/// The white underlay keeps the route readable on dense OpenStreetMap tiles.
class TrafficAwareOrderRouteLayer extends StatelessWidget {
  const TrafficAwareOrderRouteLayer({
    super.key,
    required this.routePoints,
    required this.quotedAt,
  });

  final List<LatLng> routePoints;
  final DateTime quotedAt;

  @override
  Widget build(BuildContext context) {
    return PolylineLayer(
      polylines: polylinesFor(routePoints: routePoints, quotedAt: quotedAt),
    );
  }

  static List<Polyline> polylinesFor({
    required List<LatLng> routePoints,
    required DateTime quotedAt,
  }) {
    final trafficSegments = DeliveryTrafficRouteAnalyzer.analyze(
      routePoints: routePoints,
      quotedAt: quotedAt,
    );
    return [
      Polyline(
        points: routePoints,
        color: Colors.white.withValues(alpha: 0.92),
        strokeWidth: 9,
      ),
      for (final segment in trafficSegments)
        Polyline(
          points: segment.points,
          color: deliveryTrafficColor(segment.level),
          strokeWidth: 5,
        ),
    ];
  }
}
