import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'address_search_result.dart';

class AddressSearchService {
  AddressSearchService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AddressSearchResult>> search(
    String query, {
    LatLng? proximity,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 3) return const [];

    final queryParameters = <String, String>{
      'q': normalizedQuery,
      'limit': '5',
      'countrycode': 'VN',
      if (proximity != null) ...{
        'lat': proximity.latitude.toString(),
        'lon': proximity.longitude.toString(),
        'zoom': '12',
      },
    };
    final uri = Uri.https('photon.komoot.io', '/api/', queryParameters);
    final response = await _client
        .get(
          uri,
          headers: const {
            'User-Agent': 'DATN-GiaoHang/1.0 (com.datn.giaohang)',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw AddressSearchException(
        'Photon returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    final rawFeatures = decoded is Map ? decoded['features'] : null;
    if (rawFeatures is! List) {
      throw const AddressSearchException(
        'Photon returned an invalid search response.',
      );
    }

    final results = <AddressSearchResult>[];
    final seen = <String>{};
    for (final feature in rawFeatures) {
      if (feature is! Map) continue;
      try {
        final result = AddressSearchResult.fromPhotonFeature(
          Map<String, dynamic>.from(feature),
        );
        final key =
            '${result.position.latitude.toStringAsFixed(6)}:'
            '${result.position.longitude.toStringAsFixed(6)}';
        if (seen.add(key)) results.add(result);
      } on FormatException {
        // Ignore malformed results while keeping other valid suggestions.
      }
    }
    return results;
  }

  void dispose() => _client.close();
}

class AddressSearchException implements Exception {
  const AddressSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
