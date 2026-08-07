import 'package:latlong2/latlong.dart';

/// Chính sách hiển thị vị trí tài xế trên map khách.
///
/// Realtime là nguồn chính. Polling chỉ đóng vai trò dự phòng khi socket không
/// gửi mẫu mới đủ lâu; marker được nội suy giữa hai mẫu để không nhảy từng nấc.
class TrackingLocationMotion {
  const TrackingLocationMotion._();

  static const realtimeFreshFor = Duration(seconds: 6);

  static bool shouldPollFallback({
    required DateTime? lastRealtimeAt,
    required DateTime now,
  }) {
    if (lastRealtimeAt == null) return true;
    return now.difference(lastRealtimeAt) >= realtimeFreshFor;
  }

  static LatLng interpolate(LatLng from, LatLng to, double progress) {
    final t = progress.clamp(0.0, 1.0);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }
}
