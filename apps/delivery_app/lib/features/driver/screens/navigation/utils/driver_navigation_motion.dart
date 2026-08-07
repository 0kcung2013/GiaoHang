import 'package:latlong2/latlong.dart';

/// Nội suy vị trí chỉ cho lớp hiển thị trên bản đồ điều hướng.
///
/// Tọa độ GPS đã snap vẫn là dữ liệu chính xác để tính trạng thái và gửi lên
/// server; nội suy giúp icon đi liên tục giữa hai lần nhận mẫu GPS.
class DriverNavigationMotion {
  const DriverNavigationMotion._();

  static LatLng interpolate(LatLng from, LatLng to, double progress) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }
}
