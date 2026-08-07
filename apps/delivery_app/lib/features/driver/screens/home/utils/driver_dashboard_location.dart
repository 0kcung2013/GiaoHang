import 'package:latlong2/latlong.dart';

import '../../../../../core/utils/geo_utils.dart';

/// Cho dashboard dùng cùng tọa độ với pipeline GPS đã publish.
///
/// GPS thô của thiết bị phải qua [GeoUtils] ở debug; vị trí đã lưu trong
/// Supabase thì đã được xử lý trước đó nên không được áp dụng lần thứ hai.
LatLng? resolveDriverDashboardPosition({
  required String? email,
  double? rawLat,
  double? rawLng,
  double? storedLat,
  double? storedLng,
}) {
  if (_isValid(rawLat, rawLng)) {
    return GeoUtils.applyTestDriverOffset(
      email: email,
      lat: rawLat!,
      lng: rawLng!,
    );
  }
  if (_isValid(storedLat, storedLng)) {
    return LatLng(storedLat!, storedLng!);
  }
  return null;
}

bool _isValid(double? lat, double? lng) =>
    lat != null && lng != null && (lat != 0 || lng != 0);
