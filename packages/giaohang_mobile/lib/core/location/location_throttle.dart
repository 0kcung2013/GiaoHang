import '../utils/geo_utils.dart';
import 'location_ingest_config.dart';

/// Quyết định có chấp nhận sample GPS mới hay bỏ (throttle thời gian + khoảng cách).
class LocationThrottle {
  LocationThrottle({
    this.minInterval = LocationIngestConfig.minInterval,
    this.minDistanceMeters = LocationIngestConfig.minDistanceMeters,
  });

  final Duration minInterval;
  final double minDistanceMeters;

  DateTime? _lastAcceptedAt;
  double? _lastLat;
  double? _lastLng;

  /// true = được phép ingest; false = bỏ sample (quá dày / gần như đứng yên).
  bool shouldAccept({required double lat, required double lng, DateTime? now}) {
    final t = now ?? DateTime.now();
    final lastAt = _lastAcceptedAt;
    final lastLat = _lastLat;
    final lastLng = _lastLng;

    if (lastAt == null || lastLat == null || lastLng == null) {
      _accept(t, lat, lng);
      return true;
    }

    final elapsed = t.difference(lastAt);
    if (elapsed < minInterval) {
      return false;
    }

    final moved = GeoUtils.distanceMeters(
      fromLat: lastLat,
      fromLng: lastLng,
      toLat: lat,
      toLng: lng,
    );

    // Đứng yên lâu: vẫn cho 1 nhịp theo minInterval để realtime không “đóng băng”
    // nhưng không spam khi rung GPS nhỏ.
    if (moved < minDistanceMeters && elapsed < minInterval * 3) {
      return false;
    }

    _accept(t, lat, lng);
    return true;
  }

  void _accept(DateTime t, double lat, double lng) {
    _lastAcceptedAt = t;
    _lastLat = lat;
    _lastLng = lng;
  }

  void reset() {
    _lastAcceptedAt = null;
    _lastLat = null;
    _lastLng = null;
  }
}
