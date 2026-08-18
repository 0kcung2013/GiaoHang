import 'dart:convert';

import 'package:http/http.dart' as http;

class RiskLocationAddressService {
  const RiskLocationAddressService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<String> resolve(double latitude, double longitude) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'accept-language': 'vi',
      'addressdetails': '1',
      'zoom': '18',
      'layer': 'address',
    });
    final ownedClient = _client == null ? http.Client() : null;
    final client = _client ?? ownedClient!;
    try {
      final response = await client
          .get(
            uri,
            headers: const {
              'User-Agent': 'DATN-GiaoHang/1.0 (com.datn.giaohang)',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw StateError('Nominatim HTTP ${response.statusCode}');
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Invalid reverse geocoding response');
      }
      final address = payload['display_name']?.toString().trim() ?? '';
      if (address.isEmpty) throw const FormatException('Address is empty');
      return address;
    } finally {
      ownedClient?.close();
    }
  }
}
