import 'package:latlong2/latlong.dart';

/// Làm mượt các bước nhảy ngắn của GPS sau khi đã snap vào tuyến đường.
class DriverNavigationPositionSmoother {
  DriverNavigationPositionSmoother._();

  static const _jitterMeters = 3.0;
  static const _largeJumpMeters = 150.0;
  static const _followRatio = 0.42;

  static LatLng smooth({required LatLng previous, required LatLng next}) {
    final distance = const Distance().as(LengthUnit.Meter, previous, next);
    if (distance <= _jitterMeters) return previous;
    if (distance >= _largeJumpMeters) return next;

    return LatLng(
      previous.latitude + (next.latitude - previous.latitude) * _followRatio,
      previous.longitude + (next.longitude - previous.longitude) * _followRatio,
    );
  }
}
