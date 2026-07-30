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

  /// Offset test 2 tài xế / 1 máy.
  ///
  /// Mặc định chỉ bật trong debug (`flutter run`) và tự tắt ở release.
  /// Có thể ghi đè bằng:
  /// `--dart-define=ENABLE_TEST_DRIVER_OFFSETS=false`.
  static const bool enableTestDriverOffsets = bool.fromEnvironment(
    'ENABLE_TEST_DRIVER_OFFSETS',
    defaultValue: kDebugMode,
  );

  /// `taixe2@gmail.com` lệch ~3km ĐN so với GPS thật (chỉ khi [enableTestDriverOffsets]).
  static const Map<String, LatLng> testDriverPositionOffsets = {
    'taixe2@gmail.com': LatLng(0.022, 0.018),
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
