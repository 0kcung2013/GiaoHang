import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/reverse_geocode_result.dart';

class ReverseGeocodingService {
  ReverseGeocodingService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<ReverseGeocodeResult> resolve(LatLng position) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': position.latitude.toString(),
      'lon': position.longitude.toString(),
      'accept-language': 'vi',
      'addressdetails': '1',
      'zoom': '18',
      'layer': 'address',
    });
    final response = await _client
        .get(
          uri,
          headers: const {
            'User-Agent': 'DATN-GiaoHang/1.0 (com.datn.giaohang)',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw ReverseGeocodingException(
        'Nominatim returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ReverseGeocodingException(
        'Nominatim returned an invalid response.',
      );
    }
    final result = ReverseGeocodeResult.fromNominatimJson(decoded);
    if (result.displayAddress.trim().isEmpty) {
      throw const ReverseGeocodingException(
        'No address was found for this position.',
      );
    }
    return result;
  }

  void dispose() => _client.close();
}

class ReverseGeocodingException implements Exception {
  const ReverseGeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}
