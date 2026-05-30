class DriverModel {
  const DriverModel({
    required this.id,
    required this.userId,
    this.vehicleType,
    this.licensePlate,
    required this.isAvailable,
    this.currentLat,
    this.currentLng,
    required this.updatedAt,
    this.rating,
    required this.totalDeliveries,
  });

  final String id;
  final String userId;
  final String? vehicleType;
  final String? licensePlate;
  final bool isAvailable;
  final double? currentLat;
  final double? currentLng;
  final DateTime updatedAt;
  final double? rating;
  final int totalDeliveries;

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString(),
      licensePlate: json['license_plate']?.toString(),
      isAvailable: json['is_available'] as bool? ?? false,
      currentLat: _parseDouble(json['current_lat']),
      currentLng: _parseDouble(json['current_lng']),
      updatedAt:
          _parseDateTime(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      rating: _parseDouble(json['rating']),
      totalDeliveries: _parseInt(json['total_deliveries']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'vehicle_type': vehicleType,
      'license_plate': licensePlate,
      'is_available': isAvailable,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'updated_at': updatedAt.toIso8601String(),
      'rating': rating,
      'total_deliveries': totalDeliveries,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}