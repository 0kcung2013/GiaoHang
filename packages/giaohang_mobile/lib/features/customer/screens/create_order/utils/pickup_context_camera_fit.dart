import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Show both stops while keeping the editable delivery pin at camera center.
/// Fitting to their midpoint would silently move the selected delivery address.
class PickupContextCameraFit extends CameraFit {
  const PickupContextCameraFit({required this.pickup, required this.selection});
  final LatLng pickup;
  final LatLng selection;

  @override
  MapCamera fit(MapCamera camera) {
    if (const Distance().as(LengthUnit.Meter, pickup, selection) < 10) {
      return camera.withPosition(center: selection, zoom: 17);
    }
    final fitted = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([pickup, selection]),
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 68),
      minZoom: 0,
      maxZoom: 18,
    ).fit(camera);
    // Twice the fitted span contains the other endpoint even with selection
    // fixed at the center. Zooming/fitting never changes the draft address.
    return camera.withPosition(
      center: selection,
      zoom: (fitted.zoom - 1).clamp(0, 18),
    );
  }
}
