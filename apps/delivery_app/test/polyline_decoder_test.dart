import 'package:delivery_app/core/utils/polyline_decoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('decodePolyline', () {
    test('decode empty string returns empty list', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('decode simple polyline', () {
      final result = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(result.length, 3);
      expect(result[0].latitude, closeTo(38.5, 0.00001));
      expect(result[0].longitude, closeTo(-120.2, 0.00001));
      expect(result[1].latitude, closeTo(40.7, 0.00001));
      expect(result[1].longitude, closeTo(-120.95, 0.00001));
      expect(result[2].latitude, closeTo(43.252, 0.00001));
      expect(result[2].longitude, closeTo(-126.453, 0.00001));
    });

    test('decode polyline preserves LatLng type', () {
      final result = decodePolyline('_p~iF~ps|U');
      expect(result.length, 1);
      expect(result.first, isA<LatLng>());
    });
  });
}
