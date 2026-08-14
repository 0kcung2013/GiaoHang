import 'package:latlong2/latlong.dart';

import '../../../../../core/models/reverse_geocode_result.dart';

class AddressSearchResult {
  const AddressSearchResult({
    required this.position,
    required this.resolvedAddress,
    required this.displayAddress,
    required this.rawDisplayName,
  });

  final LatLng position;
  final ReverseGeocodeResult resolvedAddress;
  final String displayAddress;
  final String rawDisplayName;

  factory AddressSearchResult.fromNominatimJson(Map<String, dynamic> json) {
    final lat = _parseCoordinate(json['lat']);
    final lng = _parseCoordinate(json['lon']);
    if (lat == null || lng == null) {
      throw const FormatException(
        'Nominatim search result does not contain valid coordinates.',
      );
    }

    final address = ReverseGeocodeResult.fromNominatimJson(json);
    final rawDisplayName = json['display_name']?.toString().trim() ?? '';
    final displayAddress = address.displayAddress.trim().isNotEmpty
        ? address.displayAddress.trim()
        : rawDisplayName;

    if (displayAddress.isEmpty) {
      throw const FormatException(
        'Nominatim search result does not contain an address.',
      );
    }

    return AddressSearchResult(
      position: LatLng(lat, lng),
      resolvedAddress: address,
      displayAddress: displayAddress,
      rawDisplayName: rawDisplayName,
    );
  }

  factory AddressSearchResult.fromPhotonFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'];
    final rawCoordinates = geometry is Map ? geometry['coordinates'] : null;
    if (rawCoordinates is! List || rawCoordinates.length < 2) {
      throw const FormatException(
        'Photon search result does not contain valid coordinates.',
      );
    }

    final lng = _parseCoordinate(rawCoordinates[0]);
    final lat = _parseCoordinate(rawCoordinates[1]);
    if (lat == null || lng == null) {
      throw const FormatException(
        'Photon search result does not contain valid coordinates.',
      );
    }

    final rawProperties = feature['properties'];
    if (rawProperties is! Map) {
      throw const FormatException(
        'Photon search result does not contain address properties.',
      );
    }
    final properties = rawProperties.map(
      (key, value) => MapEntry(key.toString(), value?.toString().trim()),
    );

    final houseNumber = _firstNonEmpty(properties, const ['housenumber']);
    final name = _firstNonEmpty(properties, const ['name']);
    final type = _firstNonEmpty(properties, const ['type']);
    final street = _firstNonEmpty(properties, const ['street']);
    final road = street ?? (type == 'street' ? name : null);
    final placeName = name != null && name != road ? name : null;
    final locality = _firstNonEmpty(properties, const ['locality']);
    final district = _firstNonEmpty(properties, const ['district', 'county']);
    final city = _firstNonEmpty(properties, const ['city']);
    final state = _firstNonEmpty(properties, const ['state']);
    final country = _firstNonEmpty(properties, const ['country']);

    final primaryAddress = houseNumber != null && road != null
        ? '$houseNumber $road'
        : road ?? placeName;
    final parts = <String>[
      ?primaryAddress,
      if (placeName != null && placeName != primaryAddress) placeName,
      ?locality,
      ?district,
      ?city,
      ?state,
    ];
    final uniqueParts = _uniqueAddressParts(parts);
    if (uniqueParts.isEmpty) {
      throw const FormatException(
        'Photon search result does not contain an address.',
      );
    }

    final displayAddress = uniqueParts.join(', ');
    final rawParts = <String>[...uniqueParts, ?country];
    final rawDisplayName = _uniqueAddressParts(rawParts).join(', ');

    return AddressSearchResult(
      position: LatLng(lat, lng),
      resolvedAddress: ReverseGeocodeResult(
        displayAddress: displayAddress,
        rawDisplayName: rawDisplayName,
        houseNumber: houseNumber,
      ),
      displayAddress: displayAddress,
      rawDisplayName: rawDisplayName,
    );
  }
}

double? _parseCoordinate(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String? _firstNonEmpty(
  Map<String, String?> values,
  List<String> candidateKeys,
) {
  for (final key in candidateKeys) {
    final value = values[key];
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

List<String> _uniqueAddressParts(Iterable<String> parts) {
  final uniqueParts = <String>[];
  for (final part in parts) {
    if (!uniqueParts.any(
      (value) => value.toLowerCase() == part.toLowerCase(),
    )) {
      uniqueParts.add(part);
    }
  }
  return uniqueParts;
}
