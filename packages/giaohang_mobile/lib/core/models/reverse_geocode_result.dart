class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    required this.displayAddress,
    required this.rawDisplayName,
    this.houseNumber,
  });

  final String displayAddress;
  final String rawDisplayName;
  final String? houseNumber;

  bool get hasHouseNumber => houseNumber?.trim().isNotEmpty == true;

  factory ReverseGeocodeResult.fromNominatimJson(Map<String, dynamic> json) {
    final rawDisplayName = json['display_name']?.toString().trim() ?? '';
    final rawAddress = json['address'];
    final address = rawAddress is Map
        ? rawAddress.map(
            (key, value) => MapEntry(key.toString(), value?.toString()),
          )
        : const <String, String?>{};

    final houseNumber = _firstValue(address, const [
      'house_number',
      'house_name',
    ]);
    final road = _firstValue(address, const [
      'road',
      'pedestrian',
      'residential',
      'footway',
    ]);
    final neighbourhood = _firstValue(address, const [
      'neighbourhood',
      'quarter',
      'suburb',
      'village',
    ]);
    final district = _firstValue(address, const [
      'city_district',
      'district',
      'borough',
      'county',
    ]);
    final city = _firstValue(address, const [
      'city',
      'town',
      'municipality',
      'state',
    ]);

    final parts = <String>[
      ?houseNumber,
      ?road,
      ?neighbourhood,
      ?district,
      ?city,
    ];
    final uniqueParts = <String>[];
    for (final part in parts) {
      if (!uniqueParts.any(
        (value) => value.toLowerCase() == part.toLowerCase(),
      )) {
        uniqueParts.add(part);
      }
    }

    return ReverseGeocodeResult(
      displayAddress: uniqueParts.length >= 2
          ? uniqueParts.join(', ')
          : rawDisplayName,
      rawDisplayName: rawDisplayName,
      houseNumber: houseNumber,
    );
  }

  String addressWithDetail(String detail) {
    final normalizedDetail = detail.trim();
    if (normalizedDetail.isEmpty) return displayAddress;
    if (displayAddress.toLowerCase().startsWith(
      normalizedDetail.toLowerCase(),
    )) {
      return displayAddress;
    }
    return '$normalizedDetail, $displayAddress';
  }
}

String? _firstValue(Map<String, String?> values, List<String> keys) {
  for (final key in keys) {
    final value = values[key]?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
