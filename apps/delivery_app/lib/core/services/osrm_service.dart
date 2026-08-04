import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../utils/polyline_decoder.dart';

class OsrmNavigationStep {
  const OsrmNavigationStep({
    required this.location,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverType,
    required this.modifier,
    required this.roadName,
  });

  final LatLng location;
  final double distanceMeters;
  final double durationSeconds;
  final String maneuverType;
  final String modifier;
  final String roadName;

  String get instruction {
    final road = roadName.trim().isEmpty ? '' : ' vào $roadName';
    return switch (maneuverType) {
      'depart' => road.isEmpty ? 'Bắt đầu di chuyển' : 'Đi theo $roadName',
      'arrive' => 'Bạn sắp đến điểm đích',
      'roundabout' || 'rotary' => 'Đi vào vòng xuyến$road',
      'merge' => 'Nhập làn$road',
      'fork' => '${_directionVerb('Giữ')}$road',
      'on ramp' => '${_directionVerb('Đi theo lối')}$road',
      'off ramp' => '${_directionVerb('Ra theo lối')}$road',
      'end of road' => '${_directionVerb('Rẽ')}$road',
      'continue' || 'new name' =>
        modifier == 'straight'
            ? 'Tiếp tục đi thẳng$road'
            : '${_directionVerb('Đi')}$road',
      'turn' => '${_directionVerb('Rẽ')}$road',
      _ =>
        modifier == 'straight'
            ? 'Tiếp tục đi thẳng$road'
            : '${_directionVerb('Đi')}$road',
    };
  }

  String _directionVerb(String prefix) {
    return switch (modifier) {
      'left' => '$prefix trái',
      'slight left' => '$prefix chếch trái',
      'sharp left' => '$prefix ngoặt trái',
      'right' => '$prefix phải',
      'slight right' => '$prefix chếch phải',
      'sharp right' => '$prefix ngoặt phải',
      'uturn' => 'Quay đầu',
      _ => '$prefix thẳng',
    };
  }
}

class OsrmRouteResult {
  const OsrmRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.steps = const [],
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<OsrmNavigationStep> steps;

  double get distanceKm => distanceMeters / 1000;
  double get durationMinutes => durationSeconds / 60;
}

class OsrmService {
  OsrmService();

  static const String _baseUrl = 'https://router.project-osrm.org';

  List<LatLng> _filterPoints(List<LatLng> points, List<LatLng> waypoints) {
    if (points.isEmpty || waypoints.isEmpty) return waypoints;

    final lats = waypoints.map((w) => w.latitude);
    final lngs = waypoints.map((w) => w.longitude);

    // Padding ~55km per degree
    const pad = 0.5;
    final minLat = lats.reduce(min) - pad;
    final maxLat = lats.reduce(max) + pad;
    final minLng = lngs.reduce(min) - pad;
    final maxLng = lngs.reduce(max) + pad;

    final filtered = points.where((p) {
      return p.latitude >= minLat &&
          p.latitude <= maxLat &&
          p.longitude >= minLng &&
          p.longitude <= maxLng;
    }).toList();

    final badCount = points.length - filtered.length;

    if (badCount > 0) {
      debugPrint(
        '[OSRM] Filtered $badCount/${points.length} bad point(s) outside bbox',
      );
    }

    // Nếu > 50% điểm bị lọc, route OSRM không đáng tin
    // → fallback về đường thẳng dùng waypoints gốc
    if (filtered.length < points.length / 2) {
      debugPrint(
        '[OSRM] Route unreliable ($badCount/${points.length} filtered). '
        'Falling back to direct line (${waypoints.length} waypoints).',
      );
      return waypoints;
    }

    if (filtered.isNotEmpty) {
      final sample = [
        ...filtered.take(3),
        if (filtered.length > 3) filtered.last,
      ];
      debugPrint(
        '[OSRM] Route sample (${filtered.length} pts): '
        '${sample.map((p) => '(${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)})').join(' → ')}',
      );
    }

    return filtered;
  }

  Future<OsrmRouteResult?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/route/v1/driving/$startLng,$startLat;$endLng,$endLat'
        '?overview=full&geometries=polyline&steps=true',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final routes = data['routes'] as List?;

      if (routes == null || routes.isEmpty) return null;

      final route = routes.first;
      final geometry = route['geometry'] as String?;
      final distance = (route['distance'] as num?)?.toDouble() ?? 0;
      final duration = (route['duration'] as num?)?.toDouble() ?? 0;

      if (geometry == null || geometry.isEmpty) return null;

      final waypoints = [LatLng(startLat, startLng), LatLng(endLat, endLng)];
      final points = _filterPoints(decodePolyline(geometry), waypoints);

      return OsrmRouteResult(
        points: points,
        distanceMeters: distance,
        durationSeconds: duration,
        steps: _parseNavigationSteps(route),
      );
    } catch (_) {
      return null;
    }
  }

  Future<OsrmRouteResult?> getRouteWithWaypoints({
    required List<LatLng> waypoints,
  }) async {
    if (waypoints.length < 2) return null;

    try {
      final coords = waypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');

      final url = Uri.parse(
        '$_baseUrl/route/v1/driving/$coords'
        '?overview=full&geometries=polyline&steps=true',
      );

      debugPrint('[OSRM] GET $url');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('[OSRM] HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final routes = data['routes'] as List?;

      if (routes == null || routes.isEmpty) return null;

      final route = routes.first;
      final geometry = route['geometry'] as String?;
      final distance = (route['distance'] as num?)?.toDouble() ?? 0;
      final duration = (route['duration'] as num?)?.toDouble() ?? 0;

      if (geometry == null || geometry.isEmpty) return null;

      final decoded = decodePolyline(geometry);
      debugPrint('[OSRM] Decoded ${decoded.length} points (before filter)');

      final points = _filterPoints(decoded, waypoints);
      debugPrint(
        '[OSRM] ${points.length} points after filter, dist=${distance.toStringAsFixed(0)}m',
      );

      return OsrmRouteResult(
        points: points,
        distanceMeters: distance,
        durationSeconds: duration,
        steps: _parseNavigationSteps(route),
      );
    } catch (e) {
      debugPrint('[OSRM] Error: $e');
      return null;
    }
  }

  List<OsrmNavigationStep> _parseNavigationSteps(dynamic route) {
    if (route is! Map) return const [];
    final legs = route['legs'];
    if (legs is! List) return const [];

    final result = <OsrmNavigationStep>[];
    for (final leg in legs) {
      if (leg is! Map || leg['steps'] is! List) continue;
      for (final rawStep in leg['steps'] as List) {
        if (rawStep is! Map || rawStep['maneuver'] is! Map) continue;
        final maneuver = rawStep['maneuver'] as Map;
        final location = maneuver['location'];
        if (location is! List || location.length < 2) continue;
        final lng = location[0];
        final lat = location[1];
        if (lat is! num || lng is! num) continue;

        result.add(
          OsrmNavigationStep(
            location: LatLng(lat.toDouble(), lng.toDouble()),
            distanceMeters: (rawStep['distance'] as num?)?.toDouble() ?? 0,
            durationSeconds: (rawStep['duration'] as num?)?.toDouble() ?? 0,
            maneuverType: maneuver['type']?.toString() ?? '',
            modifier: maneuver['modifier']?.toString() ?? 'straight',
            roadName: rawStep['name']?.toString() ?? '',
          ),
        );
      }
    }
    return result;
  }
}
