class DriverLocationModel {
  const DriverLocationModel({
    required this.id,
    required this.driverId,
    required this.lat,
    required this.lng,
    this.heading,
    this.speed,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String driverId;
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final bool isActive;
  final DateTime createdAt;

  factory DriverLocationModel.fromJson(Map<String, dynamic> json) {
    return DriverLocationModel(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      lat: _parseDouble(json['lat']) ?? 0,
      lng: _parseDouble(json['lng']) ?? 0,
      heading: _parseDouble(json['heading']),
      speed: _parseDouble(json['speed']),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
