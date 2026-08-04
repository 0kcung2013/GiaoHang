import 'package:flutter/foundation.dart';
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

  /// Offset test 3 tài xế / 1 vị trí GPS thật.
  ///
  /// Mặc định chỉ bật trong debug (`flutter run`) và tự tắt ở release.
  /// Có thể ghi đè bằng:
  /// `--dart-define=ENABLE_TEST_DRIVER_OFFSETS=false`.
  static const bool enableTestDriverOffsets = bool.fromEnvironment(
    'ENABLE_TEST_DRIVER_OFFSETS',
    defaultValue: kDebugMode,
  );

  /// `taixe2@gmail.com` lệch ~3 km Đông Nam so với GPS thật.
  /// `taixe3@gmail.com` nằm tiếp ~1 km cùng hướng để demo chuỗi
  /// taixe3 → taixe2 → taixe khi pickup đặt gần taixe3.
  static const Map<String, LatLng> testDriverPositionOffsets = {
    'taixe2@gmail.com': LatLng(0.022, 0.018),
    'taixe3@gmail.com': LatLng(0.0293, 0.024),
  };

  /// Tài khoản có được cấu hình offset demo hay không.
  static bool hasConfiguredTestDriverOffset(String? email) {
    final key = email?.trim().toLowerCase();
    return key != null && testDriverPositionOffsets.containsKey(key);
  }

  /// Tài khoản có đang được áp offset demo hay không.
  static bool hasTestDriverOffset(String? email) {
    return enableTestDriverOffsets && hasConfiguredTestDriverOffset(email);
  }

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
