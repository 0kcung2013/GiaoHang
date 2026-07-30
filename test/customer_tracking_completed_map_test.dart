import 'package:customer_app/features/customer/screens/tracking/utils/tracking_map_phase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('customer tracking completed map', () {
    const pickup = LatLng(11.0251, 106.6234);
    const delivery = LatLng(11.0394, 106.6298);
    const latestDriverProfile = LatLng(11.0526, 106.6399);

    test('freezes the driver at the confirmed delivery point', () {
      final phase = TrackingMapPhase.fromStatus('delivered');

      expect(phase.tracksLiveDriver, isFalse);
      expect(
        phase.visibleDriverPosition(
          latestDriverPosition: latestDriverProfile,
          delivery: delivery,
        ),
        delivery,
      );
      expect(phase.legend, 'L → G · đã giao hàng');
    });

    test('shows the completed pickup-to-delivery route', () {
      final phase = TrackingMapPhase.fromStatus('delivered');
      final waypoints = phase.routeWaypoints(
        driver: latestDriverProfile,
        pickup: pickup,
        delivery: delivery,
      );

      expect(waypoints, [pickup, delivery]);
      expect(
        phase.cameraPoints(
          driver: latestDriverProfile,
          pickup: pickup,
          delivery: delivery,
        ),
        [pickup, delivery],
      );
    });
  });
}
