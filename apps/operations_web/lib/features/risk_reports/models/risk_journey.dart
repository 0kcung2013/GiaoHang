import 'package:latlong2/latlong.dart';

class RiskJourneyPoint {
  const RiskJourneyPoint(this.position, this.time, this.driverId);
  final LatLng position;
  final DateTime time;
  final String driverId;
  factory RiskJourneyPoint.fromJson(Map<String, dynamic> json) =>
      RiskJourneyPoint(
        LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        DateTime.parse(json['created_at'] as String),
        json['driver_id'] as String? ?? '',
      );
}

class RiskJourney {
  RiskJourney(Iterable<RiskJourneyPoint> source, {this.unavailableChunks = 0}) {
    final unique = <String, RiskJourneyPoint>{};
    for (final point in source) {
      unique['${point.driverId}/${point.time.toIso8601String()}/${point.position}'] =
          point;
    }
    points = unique.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  }
  late final List<RiskJourneyPoint> points;
  final int unavailableChunks;

  int closestIndex(DateTime time) {
    var closest = 0;
    for (var i = 1; i < points.length; i++) {
      if (points[i].time.difference(time).abs() <
          points[closest].time.difference(time).abs()) {
        closest = i;
      }
    }
    return closest;
  }

  /// Không nối qua khoảng thiếu mẫu >60 giây, đổi tài xế hoặc bước nhảy GPS.
  late final List<List<LatLng>> segments = _buildSegments();

  List<List<LatLng>> _buildSegments() {
    final result = <List<LatLng>>[];
    RiskJourneyPoint? previous;
    for (final point in points) {
      final seconds = previous == null
          ? 0
          : point.time.difference(previous.time).inMilliseconds / 1000;
      final split =
          previous == null ||
          point.driverId != previous.driverId ||
          seconds > 60 ||
          seconds <= 0 ||
          const Distance().as(
                    LengthUnit.Meter,
                    previous.position,
                    point.position,
                  ) /
                  seconds >
              150 / 3.6;
      if (split) result.add([]);
      result.last.add(point.position);
      previous = point;
    }
    return result;
  }
}
