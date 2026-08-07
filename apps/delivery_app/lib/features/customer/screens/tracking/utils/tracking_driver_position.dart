import 'package:latlong2/latlong.dart';

import '../../../../../core/utils/geo_utils.dart';

class TrackingDriverPositionResolver {
  const TrackingDriverPositionResolver._();

  static LatLng? resolve({
    required LatLng? live,
    required LatLng? profile,
    required LatLng? stable,
    String? demoEmail,
  }) {
    final source = _isValid(live)
        ? live
        : _isValid(profile)
        ? profile
        : _isValid(stable)
        ? stable
        : null;
    if (source == null) return null;

    return GeoUtils.applyTestDriverOffset(
      email: demoEmail,
      lat: source.latitude,
      lng: source.longitude,
    );
  }

  static bool _isValid(LatLng? point) {
    return point != null && point.latitude != 0.0 && point.longitude != 0.0;
  }
}
