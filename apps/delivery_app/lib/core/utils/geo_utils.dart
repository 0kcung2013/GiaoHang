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

  /// Ba GPS cố định quanh hai tuyến AI mẫu ở TP.HCM.
  ///
  /// `taixe` và `taixe2` nằm trên/gần hai tuyến AI mẫu trung tâm; `taixe3`
  /// nằm ở phía bắc để kiểm thử tải đơn. Vì vậy test phân công và OSRM luôn
  /// tái lập được dù GPS thiết bị thật đang ở đâu. Chỉ có hiệu lực ở debug.
  static const Map<String, LatLng> testDriverDemoPositions = {
    'taixe@gmail.com': LatLng(10.7790, 106.6765),
    'taixe2@gmail.com': LatLng(10.8080, 106.6810),
    'taixe3@gmail.com': LatLng(10.8520, 106.6170),
  };

  /// Tài khoản có được cấu hình offset demo hay không.
  static bool hasConfiguredTestDriverOffset(String? email) {
    final key = email?.trim().toLowerCase();
    return key != null && testDriverDemoPositions.containsKey(key);
  }

  /// Tài khoản có đang được áp offset demo hay không.
  static bool hasTestDriverOffset(String? email) {
    return enableTestDriverOffsets && hasConfiguredTestDriverOffset(email);
  }

  /// Áp vị trí GPS demo cố định theo email tài xế (nếu bật flag + có mapping).
  static LatLng applyTestDriverOffset({
    required String? email,
    required double lat,
    required double lng,
  }) {
    if (!enableTestDriverOffsets) return LatLng(lat, lng);
    final key = email?.trim().toLowerCase();
    if (key == null || key.isEmpty) return LatLng(lat, lng);
    return testDriverDemoPositions[key] ?? LatLng(lat, lng);
  }
}
