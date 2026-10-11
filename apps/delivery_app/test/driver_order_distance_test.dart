import 'package:delivery_app/features/driver/screens/home/utils/driver_order_distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats the distance as the total of two legs', () {
    expect(totalOrderDistanceText(2750), 'Tổng 2 chặng · ~2.8 km');
  });

  test('formats prominent distance values in kilometers', () {
    expect(distanceKilometersText(850), '0.8 km');
    expect(distanceKilometersText(2750), '2.8 km');
    expect(distanceKilometersText(12750), '12.8 km');
    expect(distanceKilometersText(null), '—');
  });
}
