import 'package:giaohang_mobile/features/driver/screens/home/utils/driver_order_distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats the distance as the total of two legs', () {
    expect(totalOrderDistanceText(2750), 'Tổng 2 chặng · ~2.8 km');
  });

  test('uses meters below one kilometer and kilometers for longer routes', () {
    expect(distanceKilometersText(850), '850 m');
    expect(distanceKilometersText(2750), '2.8 km');
    expect(distanceKilometersText(12750), '12.8 km');
    expect(distanceKilometersText(null), '—');
  });

  test('shows a short pickup leg in meters instead of zero kilometers', () {
    expect(distanceKilometersText(30), '30 m');
    expect(distanceKilometersText(49.9), '50 m');
    expect(distanceKilometersText(100), '100 m');
    expect(distanceKilometersText(600), '600 m');
  });
}
