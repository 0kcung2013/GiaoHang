import 'package:latlong2/latlong.dart';

enum DispatchMode { nearby, area, destination }

class OperatingArea {
  const OperatingArea({
    required this.id,
    required this.provinceCode,
    required this.provinceName,
    required this.name,
  });
  final String id;
  final String provinceCode;
  final String provinceName;
  final String name;

  factory OperatingArea.fromJson(Map<String, dynamic> json) => OperatingArea(
    id: json['id'] as String,
    provinceCode: json['province_code'] as String,
    provinceName: json['province_name'] as String,
    name: json['name'] as String,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'province_code': provinceCode,
    'province_name': provinceName,
    'name': name,
  };
}

class DispatchPreferences {
  const DispatchPreferences({
    this.mode = DispatchMode.nearby,
    this.areaId,
    this.destination,
    this.destinationLabel,
    this.expiresAt,
    this.nearbyDeliveryLimitMeters,
  });
  final DispatchMode mode;
  final String? areaId;
  final LatLng? destination;
  final String? destinationLabel;
  final DateTime? expiresAt;
  final int? nearbyDeliveryLimitMeters;
  bool get expired => expiresAt != null && !expiresAt!.isAfter(DateTime.now());

  factory DispatchPreferences.fromJson(Map<String, dynamic> json) {
    final lat = json['destination_lat'] as num?;
    final lng = json['destination_lng'] as num?;
    return DispatchPreferences(
      mode: DispatchMode.values.firstWhere(
        (m) => m.name == json['dispatch_mode'],
        orElse: () => DispatchMode.nearby,
      ),
      areaId: json['operating_area_id'] as String?,
      destination: lat == null || lng == null
          ? null
          : LatLng(lat.toDouble(), lng.toDouble()),
      destinationLabel: json['destination_label'] as String?,
      expiresAt: DateTime.tryParse(
        json['destination_expires_at']?.toString() ?? '',
      ),
      nearbyDeliveryLimitMeters: (json['nearby_delivery_limit_m'] as num?)
          ?.toInt(),
    );
  }
  Map<String, dynamic> toJson() => {
    'dispatch_mode': mode.name,
    'operating_area_id': areaId,
    'destination_lat': destination?.latitude,
    'destination_lng': destination?.longitude,
    'destination_label': destinationLabel,
    'destination_expires_at': expiresAt?.toUtc().toIso8601String(),
    'nearby_delivery_limit_m': nearbyDeliveryLimitMeters,
  };
}
