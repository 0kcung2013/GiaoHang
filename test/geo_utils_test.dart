import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils driver demo offset', () {
    test('dịch taixe2 khoảng 3 km khi chạy debug', () {
      expect(GeoUtils.enableTestDriverOffsets, isTrue);

      final adjusted = GeoUtils.applyTestDriverOffset(
        email: '  TAIXE2@gmail.com ',
        lat: 10.7769,
        lng: 106.7009,
      );
      final distance = GeoUtils.distanceMeters(
        fromLat: 10.7769,
        fromLng: 106.7009,
        toLat: adjusted.latitude,
        toLng: adjusted.longitude,
      );

      expect(GeoUtils.hasTestDriverOffset('taixe2@gmail.com'), isTrue);
      expect(distance, inInclusiveRange(3000, 3300));
    });

    test('không dịch các tài khoản tài xế khác', () {
      final adjusted = GeoUtils.applyTestDriverOffset(
        email: 'taixe1@gmail.com',
        lat: 10.7769,
        lng: 106.7009,
      );

      expect(adjusted.latitude, 10.7769);
      expect(adjusted.longitude, 106.7009);
      expect(GeoUtils.hasTestDriverOffset('taixe1@gmail.com'), isFalse);
    });
  });
}
