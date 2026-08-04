import 'package:delivery_app/features/driver/screens/home/utils/driver_home_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickupDistanceText', () {
    test('rounds short distances to readable 50 meter steps', () {
      expect(pickupDistanceText(824), 'cách 800 m');
      expect(pickupDistanceText(972), 'cách 950 m');
    });

    test('uses one decimal for distances below 10 kilometers', () {
      expect(pickupDistanceText(1240), 'cách 1.2 km');
      expect(pickupDistanceText(9950), 'cách 9.9 km');
    });

    test('uses whole kilometers for longer distances', () {
      expect(pickupDistanceText(12400), 'cách 12 km');
    });

    test('handles missing distance', () {
      expect(pickupDistanceText(null), 'Chưa có khoảng cách');
    });
  });
}
