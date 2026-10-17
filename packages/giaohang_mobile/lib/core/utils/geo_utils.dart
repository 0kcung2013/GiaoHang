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
  /// Bật mặc định trên Web và bản cài Android để các tài khoản demo có cùng
  /// hành vi khi trình diễn. Có thể tắt rõ ràng cho bản production bằng:
  /// `--dart-define=ENABLE_TEST_DRIVER_OFFSETS=false`.
  static const bool enableTestDriverOffsets = bool.fromEnvironment(
    'ENABLE_TEST_DRIVER_OFFSETS',
    defaultValue: true,
  );

  /// Ba GPS cố định phục vụ trình diễn ở TP.HCM.
  ///
  /// Cả ba ở đường Linh Đông, trong 2 km đường bộ đến điểm lấy của tuyến demo.
  /// Khoảng cách tăng theo `taixe` → `taixe2` → `taixe3` để demo chuyển đơn
  /// lần lượt, không bị loại khỏi danh sách mời vì tọa độ quá xa.
  static const Map<String, LatLng> testDriverDemoPositions = {
    'taixe@gmail.com': LatLng(10.84923, 106.747293),
    'taixe2@gmail.com': LatLng(10.850616, 106.747684),
    'taixe3@gmail.com': LatLng(10.8520, 106.7481),
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
