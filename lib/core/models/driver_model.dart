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
    this.approvalStatus = 'approved',
    this.fullName,
    this.email,
    this.phone,
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
  final String approvalStatus;
  final String? fullName;
  final String? email;
  final String? phone;

  DriverModel copyWith({
    String? id,
    String? userId,
    String? vehicleType,
    String? licensePlate,
    bool? isAvailable,
    double? currentLat,
    double? currentLng,
    DateTime? updatedAt,
    double? rating,
    int? totalDeliveries,
    String? approvalStatus,
    String? fullName,
    String? email,
    String? phone,
  }) {
    return DriverModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleType: vehicleType ?? this.vehicleType,
      licensePlate: licensePlate ?? this.licensePlate,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: (json['id'] ?? json['driver_id'])?.toString() ?? '',
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
      approvalStatus: json['approval_status']?.toString() ?? 'approved',
      fullName: json['full_name']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
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
      'approval_status': approvalStatus,
      'full_name': fullName,
      'email': email,
      'phone': phone,
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
