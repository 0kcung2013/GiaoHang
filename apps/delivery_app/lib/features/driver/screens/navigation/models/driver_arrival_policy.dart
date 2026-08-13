import 'package:latlong2/latlong.dart';

import 'driver_position_source.dart';

export 'driver_position_source.dart';

class DriverArrivalPolicy {
  const DriverArrivalPolicy._();

  static const double arrivalRadiusMeters = 100;

  static LatLng? resolveArrival({
    required String status,
    required LatLng current,
    required LatLng target,
    required DriverPositionSource source,
  }) {
    final isActiveLeg = status == 'picking_up' || status == 'delivering';
    if (!isActiveLeg || !source.canConfirmArrival) return null;

    final meters = const Distance().as(LengthUnit.Meter, current, target);
    return meters <= arrivalRadiusMeters ? target : null;
  }
}
