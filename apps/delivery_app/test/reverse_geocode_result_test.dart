import 'package:delivery_app/features/customer/screens/create_order/utils/reverse_geocode_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReverseGeocodeResult', () {
    test('preserves an OSM house number and formats a concise address', () {
      final result = ReverseGeocodeResult.fromNominatimJson({
        'display_name':
            '25A, Đường Nguyễn Trãi, Phường Bến Thành, Quận 1, Hồ Chí Minh, Việt Nam',
        'address': {
          'house_number': '25A',
          'road': 'Đường Nguyễn Trãi',
          'suburb': 'Phường Bến Thành',
          'city_district': 'Quận 1',
          'city': 'Hồ Chí Minh',
        },
      });

      expect(result.hasHouseNumber, isTrue);
      expect(result.houseNumber, '25A');
      expect(
        result.displayAddress,
        '25A, Đường Nguyễn Trãi, Phường Bến Thành, Quận 1, Hồ Chí Minh',
      );
      expect(
        result.addressWithDetail('Tầng 3'),
        'Tầng 3, 25A, Đường Nguyễn Trãi, Phường Bến Thành, Quận 1, Hồ Chí Minh',
      );
    });

    test(
      'reports missing house number and accepts a manual location detail',
      () {
        final result = ReverseGeocodeResult.fromNominatimJson({
          'display_name':
              'Đường Lê Văn Sỹ, Phường 13, Quận 3, Hồ Chí Minh, Việt Nam',
          'address': {
            'road': 'Đường Lê Văn Sỹ',
            'suburb': 'Phường 13',
            'city_district': 'Quận 3',
            'city': 'Hồ Chí Minh',
          },
        });

        expect(result.hasHouseNumber, isFalse);
        expect(result.houseNumber, isNull);
        expect(
          result.addressWithDetail('Hẻm 120, nhà 18'),
          'Hẻm 120, nhà 18, Đường Lê Văn Sỹ, Phường 13, Quận 3, Hồ Chí Minh',
        );
      },
    );

    test(
      'falls back to display_name when structured parts are unavailable',
      () {
        final result = ReverseGeocodeResult.fromNominatimJson({
          'display_name': 'Khu đô thị Sala, Thủ Đức, Hồ Chí Minh, Việt Nam',
        });

        expect(
          result.displayAddress,
          'Khu đô thị Sala, Thủ Đức, Hồ Chí Minh, Việt Nam',
        );
        expect(result.hasHouseNumber, isFalse);
      },
    );
  });
}
