import 'package:latlong2/latlong.dart';

class TrackingDriverPositionResolver {
  const TrackingDriverPositionResolver._();

  static LatLng? resolve({
    required LatLng? live,
    required LatLng? profile,
    required LatLng? stable,
  }) {
    final source = _isValid(live)
        ? live
        : _isValid(profile)
        ? profile
        : _isValid(stable)
        ? stable
        : null;
    // Tài xế đã gửi tọa độ bản đồ qua Realtime và drivers.current_lat/lng.
    // Áp vị trí demo lần nữa ở phía khách sẽ che mất chuyển động thực tế.
    return source;
  }

  static bool _isValid(LatLng? point) {
    return point != null && point.latitude != 0.0 && point.longitude != 0.0;
  }
}
