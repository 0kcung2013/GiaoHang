import 'package:latlong2/latlong.dart';

/// Nội suy vị trí chỉ cho lớp hiển thị trên bản đồ điều hướng.
///
/// Tọa độ GPS đã snap vẫn là dữ liệu chính xác để tính trạng thái và gửi lên
/// server; nội suy giúp icon đi liên tục giữa hai lần nhận mẫu GPS.
class DriverNavigationMotion {
  const DriverNavigationMotion._();

  static ({LatLng position, int nextRouteIndex, bool reachedEnd})
  advanceAlongRoute({
    required List<LatLng> route,
    required LatLng current,
    required int nextRouteIndex,
    required double maxDistanceMeters,
  }) {
    if (route.isEmpty) {
      return (position: current, nextRouteIndex: 0, reachedEnd: true);
    }

    var position = current;
    var index = nextRouteIndex.clamp(0, route.length);
    var remainingMeters = maxDistanceMeters.clamp(0, double.infinity);
    const distance = Distance(roundResult: false);

    while (index < route.length) {
      final target = route[index];
      final segmentMeters = distance.as(LengthUnit.Meter, position, target);

      if (segmentMeters <= remainingMeters) {
        position = target;
        remainingMeters -= segmentMeters;
        index++;
        continue;
      }

      if (remainingMeters > 0 && segmentMeters > 0) {
        position = interpolate(
          position,
          target,
          remainingMeters / segmentMeters,
        );
      }
      return (position: position, nextRouteIndex: index, reachedEnd: false);
    }

    return (position: position, nextRouteIndex: index, reachedEnd: true);
  }

  static LatLng interpolate(LatLng from, LatLng to, double progress) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }
}
