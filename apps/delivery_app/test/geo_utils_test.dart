import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/core/utils/geo_utils.dart';

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

    test('đặt taixe3 xa taixe2 khoảng 1 km trên cùng hướng demo', () {
      const baseLat = 10.7769;
      const baseLng = 106.7009;
      final taixe2 = GeoUtils.applyTestDriverOffset(
        email: 'taixe2@gmail.com',
        lat: baseLat,
        lng: baseLng,
      );
      final taixe3 = GeoUtils.applyTestDriverOffset(
        email: 'taixe3@gmail.com',
        lat: baseLat,
        lng: baseLng,
      );

      final taixe2ToTaixe3 = GeoUtils.distanceMeters(
        fromLat: taixe2.latitude,
        fromLng: taixe2.longitude,
        toLat: taixe3.latitude,
        toLng: taixe3.longitude,
      );
      final baseToTaixe3 = GeoUtils.distanceMeters(
        fromLat: baseLat,
        fromLng: baseLng,
        toLat: taixe3.latitude,
        toLng: taixe3.longitude,
      );

      expect(GeoUtils.hasTestDriverOffset('taixe3@gmail.com'), isTrue);
      expect(taixe2ToTaixe3, inInclusiveRange(900, 1200));
      expect(baseToTaixe3, inInclusiveRange(4000, 4400));
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
