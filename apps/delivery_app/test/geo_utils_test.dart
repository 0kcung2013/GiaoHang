import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/core/utils/geo_utils.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GeoUtils driver demo offset', () {
    test('dịch đủ ba tài xế quanh GPS gốc khi chạy debug', () {
      expect(GeoUtils.enableTestDriverOffsets, isTrue);

      final taixe1 = GeoUtils.applyTestDriverOffset(
        email: 'taixe@gmail.com',
        lat: 10.7769,
        lng: 106.7009,
      );
      final taixe2 = GeoUtils.applyTestDriverOffset(
        email: '  TAIXE2@gmail.com ',
        lat: 10.7769,
        lng: 106.7009,
      );
      final taixe3 = GeoUtils.applyTestDriverOffset(
        email: 'taixe3@gmail.com',
        lat: 10.7769,
        lng: 106.7009,
      );

      expect(GeoUtils.hasTestDriverOffset('taixe@gmail.com'), isTrue);
      expect(GeoUtils.hasTestDriverOffset('taixe2@gmail.com'), isTrue);
      expect(GeoUtils.hasTestDriverOffset('taixe3@gmail.com'), isTrue);
      expect(taixe1, const LatLng(10.7790, 106.6765));
      expect(taixe2, const LatLng(10.8080, 106.6810));
      expect(taixe3, const LatLng(10.8520, 106.6170));
    });

    test('giữ ba vị trí demo không chồng lên nhau', () {
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

      final taixe1 = GeoUtils.applyTestDriverOffset(
        email: 'taixe@gmail.com',
        lat: baseLat,
        lng: baseLng,
      );
      final taixe2ToTaixe3 = GeoUtils.distanceMeters(
        fromLat: taixe2.latitude,
        fromLng: taixe2.longitude,
        toLat: taixe3.latitude,
        toLng: taixe3.longitude,
      );
      final taixe1ToTaixe2 = GeoUtils.distanceMeters(
        fromLat: taixe1.latitude,
        fromLng: taixe1.longitude,
        toLat: taixe2.latitude,
        toLng: taixe2.longitude,
      );

      expect(taixe2ToTaixe3, greaterThan(2000));
      expect(taixe1ToTaixe2, greaterThan(3000));
    });
  });
}
