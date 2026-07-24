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

  /// Offset test 2 tài xế / 1 máy — **TẮT mặc định**.
  /// Bật true chỉ khi demo nearest trên cùng thiết bị (sẽ lệch map L/G).
  static const bool enableTestDriverOffsets = false;

  /// `taixe2@gmail.com` lệch ~3km ĐN so với GPS thật (chỉ khi [enableTestDriverOffsets]).
  static const Map<String, LatLng> testDriverPositionOffsets = {
    'taixe2@gmail.com': LatLng(0.022, 0.018),
  };

  /// Áp offset test theo email tài xế (nếu bật flag + có mapping).
  static LatLng applyTestDriverOffset({
    required String? email,
    required double lat,
    required double lng,
  }) {
    if (!enableTestDriverOffsets) return LatLng(lat, lng);
    final key = email?.trim().toLowerCase();
    if (key == null || key.isEmpty) return LatLng(lat, lng);
    final offset = testDriverPositionOffsets[key];
    if (offset == null) return LatLng(lat, lng);
    return LatLng(lat + offset.latitude, lng + offset.longitude);
  }
}
