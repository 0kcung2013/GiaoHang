import 'dart:convert';

import 'package:customer_app/features/customer/screens/create_order/utils/address_search_result.dart';
import 'package:customer_app/features/customer/screens/create_order/utils/address_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('AddressSearchResult', () {
    test('parses coordinates and formats a concise Vietnamese address', () {
      final result = AddressSearchResult.fromNominatimJson({
        'lat': '10.775123',
        'lon': '106.700456',
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

      expect(result.position.latitude, 10.775123);
      expect(result.position.longitude, 106.700456);
      expect(
        result.displayAddress,
        '25A, Đường Nguyễn Trãi, Phường Bến Thành, Quận 1, Hồ Chí Minh',
      );
    });

    test('rejects results without valid coordinates', () {
      expect(
        () => AddressSearchResult.fromNominatimJson({
          'display_name': 'Quận 1, Hồ Chí Minh',
        }),
        throwsFormatException,
      );
    });

    test('parses a Photon address suggestion with a house number', () {
      final result = AddressSearchResult.fromPhotonFeature({
        'geometry': {
          'type': 'Point',
          'coordinates': [106.700456, 10.775123],
        },
        'properties': {
          'type': 'house',
          'name': 'Cửa hàng ABC',
          'housenumber': '25A',
          'street': 'Nguyễn Trãi',
          'district': 'Quận 1',
          'city': 'Hồ Chí Minh',
          'country': 'Việt Nam',
        },
      });

      expect(result.position.latitude, 10.775123);
      expect(result.position.longitude, 106.700456);
      expect(result.resolvedAddress.hasHouseNumber, isTrue);
      expect(
        result.displayAddress,
        '25A Nguyễn Trãi, Cửa hàng ABC, Quận 1, Hồ Chí Minh',
      );
    });

    test(
      'keeps a Photon street suggestion without inventing a house number',
      () {
        final result = AddressSearchResult.fromPhotonFeature({
          'geometry': {
            'type': 'Point',
            'coordinates': [106.6754279, 10.981809],
          },
          'properties': {
            'type': 'street',
            'name': 'Trần Văn Ơn',
            'locality': 'Vinh Sơn',
            'district': 'Phường Phú Lợi',
            'city': 'Thành phố Hồ Chí Minh',
            'country': 'Việt Nam',
          },
        });

        expect(result.resolvedAddress.hasHouseNumber, isFalse);
        expect(
          result.displayAddress,
          'Trần Văn Ơn, Vinh Sơn, Phường Phú Lợi, Thành phố Hồ Chí Minh',
        );
      },
    );
  });

  group('AddressSearchService', () {
    test(
      'sends an explicit Vietnam-scoped search and parses results',
      () async {
        late http.Request capturedRequest;
        final client = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [106.700456, 10.775123],
                  },
                  'properties': {
                    'type': 'house',
                    'housenumber': '25A',
                    'street': 'Nguyễn Trãi',
                    'district': 'Quận 1',
                    'city': 'Hồ Chí Minh',
                    'country': 'Việt Nam',
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final service = AddressSearchService(client: client);

        final results = await service.search(
          '  25A Nguyễn Trãi  ',
          proximity: const LatLng(10.77, 106.70),
        );

        expect(results, hasLength(1));
        expect(results.single.position.latitude, 10.775123);
        expect(capturedRequest.url.host, 'photon.komoot.io');
        expect(capturedRequest.url.path, '/api/');
        expect(capturedRequest.url.queryParameters['q'], '25A Nguyễn Trãi');
        expect(capturedRequest.url.queryParameters['countrycode'], 'VN');
        expect(capturedRequest.url.queryParameters['limit'], '5');
        expect(capturedRequest.url.queryParameters['lat'], '10.77');
        expect(capturedRequest.url.queryParameters['lon'], '106.7');
        expect(
          capturedRequest.headers['User-Agent'],
          contains('DATN-GiaoHang'),
        );
        service.dispose();
      },
    );

    test(
      'does not call the API for a query shorter than three characters',
      () async {
        var callCount = 0;
        final service = AddressSearchService(
          client: MockClient((request) async {
            callCount++;
            return http.Response('[]', 200);
          }),
        );

        final results = await service.search('ab');

        expect(results, isEmpty);
        expect(callCount, 0);
        service.dispose();
      },
    );
  });
}
