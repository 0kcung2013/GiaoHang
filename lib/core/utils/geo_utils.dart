import 'package:latlong2/latlong.dart';

/// Tiện ích khoảng cách địa lý (Haversine).
class GeoUtils {
  GeoUtils._();

  static const Distance _distance = Distance();

  /// Khoảng cách mét giữa 2 điểm (lat/lng).
  static double distanceMeters({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return _distance.as(
      LengthUnit.Meter,
      LatLng(fromLat, fromLng),
      LatLng(toLat, toLng),
    );
  }

  /// Offset cố định (độ) để test 2 tài xế trên cùng 1 thiết bị.
  /// `taixe2@gmail.com` lệch ~3km về phía ĐN so với GPS thật.
  static const Map<String, LatLng> testDriverPositionOffsets = {
    'taixe2@gmail.com': LatLng(0.022, 0.018),
  };

  /// Áp offset test theo email tài xế (nếu có).
  static LatLng applyTestDriverOffset({
    required String? email,
    required double lat,
    required double lng,
  }) {
    final key = email?.trim().toLowerCase();
    if (key == null || key.isEmpty) return LatLng(lat, lng);
    final offset = testDriverPositionOffsets[key];
    if (offset == null) return LatLng(lat, lng);
    return LatLng(lat + offset.latitude, lng + offset.longitude);
  }
}
