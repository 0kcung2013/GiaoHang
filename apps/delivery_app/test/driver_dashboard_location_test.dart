import 'package:delivery_app/features/driver/screens/home/utils/driver_dashboard_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('uses the fixed TP.HCM demo GPS before calculating order distance', () {
    final position = resolveDriverDashboardPosition(
      email: 'taixe@gmail.com',
      rawLat: 21.0285,
      rawLng: 105.8542,
      storedLat: 21.0285,
      storedLng: 105.8542,
    );

    expect(position, const LatLng(10.7790, 106.6765));
  });

  test(
    'keeps the already adjusted stored position when device GPS is absent',
    () {
      final position = resolveDriverDashboardPosition(
        email: 'taixe@gmail.com',
        storedLat: 10.7790,
        storedLng: 106.6765,
      );

      expect(position, const LatLng(10.7790, 106.6765));
    },
  );
}
