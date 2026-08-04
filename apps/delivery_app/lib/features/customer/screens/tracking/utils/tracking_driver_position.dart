import 'package:latlong2/latlong.dart';

class TrackingDriverPositionResolver {
  const TrackingDriverPositionResolver._();

  static LatLng? resolve({
    required LatLng? live,
    required LatLng? profile,
    required LatLng? stable,
  }) {
    if (_isValid(live)) return live;
    if (_isValid(profile)) return profile;
    return _isValid(stable) ? stable : null;
  }

  static bool _isValid(LatLng? point) {
    return point != null && point.latitude != 0.0 && point.longitude != 0.0;
  }
}
