class DriverModel {
  const DriverModel({
    required this.id,
    required this.userId,
    this.vehicleType,
    this.licensePlate,
    this.vehicleBrandModel,
    this.vehicleColor,
    required this.isAvailable,
    this.currentLat,
    this.currentLng,
    required this.updatedAt,
    this.rating,
    this.ratingCount = 0,
    required this.totalDeliveries,
    this.approvalStatus = 'approved',
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.verifiedAt,
    this.rejectionReason,
    this.submittedAt,
    // Phase B KYC (schema ready; UI later)
    this.idCardNumber,
    this.idCardFrontUrl,
    this.idCardBackUrl,
    this.driverLicenseNumber,
    this.driverLicenseUrl,
    this.vehiclePhotoUrl,
  });

  final String id;
  final String userId;
  final String? vehicleType;
  final String? licensePlate;

  /// Phase A — e.g. Honda Wave (shown to customer).
  final String? vehicleBrandModel;

  /// Phase A — vehicle color (shown to customer).
  final String? vehicleColor;

  final bool isAvailable;
  final double? currentLat;
  final double? currentLng;
  final DateTime updatedAt;
  final double? rating;
  /// Số lượt đánh giá (reviews).
  final int ratingCount;
  final int totalDeliveries;
  final String approvalStatus;
  final String? fullName;
  final String? email;
  final String? phone;

  /// From users.avatar_url (public for assigned customer).
  final String? avatarUrl;

  final DateTime? verifiedAt;
  final String? rejectionReason;
  final DateTime? submittedAt;

  final String? idCardNumber;
  final String? idCardFrontUrl;
  final String? idCardBackUrl;
  final String? driverLicenseNumber;
  final String? driverLicenseUrl;
  final String? vehiclePhotoUrl;

  /// Customer-facing badge: approved after admin review.
  bool get isVerified => approvalStatus == 'approved';

  /// Heuristic for "Tài xế mới" badge on UI.
  bool get isNewDriver => totalDeliveries < 5;

  DriverModel copyWith({
    String? id,
    String? userId,
    String? vehicleType,
    String? licensePlate,
    String? vehicleBrandModel,
    String? vehicleColor,
    bool? isAvailable,
    double? currentLat,
    double? currentLng,
    DateTime? updatedAt,
    double? rating,
    int? ratingCount,
    int? totalDeliveries,
    String? approvalStatus,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    DateTime? verifiedAt,
    String? rejectionReason,
    DateTime? submittedAt,
    String? idCardNumber,
    String? idCardFrontUrl,
    String? idCardBackUrl,
    String? driverLicenseNumber,
    String? driverLicenseUrl,
    String? vehiclePhotoUrl,
  }) {
    return DriverModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleType: vehicleType ?? this.vehicleType,
      licensePlate: licensePlate ?? this.licensePlate,
      vehicleBrandModel: vehicleBrandModel ?? this.vehicleBrandModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      idCardNumber: idCardNumber ?? this.idCardNumber,
      idCardFrontUrl: idCardFrontUrl ?? this.idCardFrontUrl,
      idCardBackUrl: idCardBackUrl ?? this.idCardBackUrl,
      driverLicenseNumber: driverLicenseNumber ?? this.driverLicenseNumber,
      driverLicenseUrl: driverLicenseUrl ?? this.driverLicenseUrl,
      vehiclePhotoUrl: vehiclePhotoUrl ?? this.vehiclePhotoUrl,
    );
  }

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: (json['id'] ?? json['driver_id'])?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString(),
      licensePlate: json['license_plate']?.toString(),
      vehicleBrandModel: json['vehicle_brand_model']?.toString(),
      vehicleColor: json['vehicle_color']?.toString(),
      isAvailable: json['is_available'] as bool? ?? false,
      currentLat: _parseDouble(json['current_lat']),
      currentLng: _parseDouble(json['current_lng']),
      updatedAt:
          _parseDateTime(json['updated_at']) ??
          _parseDateTime(json['member_since']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      rating: _parseDouble(json['rating']),
      ratingCount: _parseInt(json['rating_count']) ?? 0,
      totalDeliveries: _parseInt(json['total_deliveries']) ?? 0,
      approvalStatus: json['approval_status']?.toString() ??
          ((json['is_verified'] == true) ? 'approved' : 'pending'),
      fullName: json['full_name']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      verifiedAt: _parseDateTime(json['verified_at']) ??
          (json['is_verified'] == true
              ? _parseDateTime(json['member_since'])
              : null),
      rejectionReason: json['rejection_reason']?.toString(),
      submittedAt: _parseDateTime(json['submitted_at']),
      idCardNumber: json['id_card_number']?.toString(),
      idCardFrontUrl: json['id_card_front_url']?.toString(),
      idCardBackUrl: json['id_card_back_url']?.toString(),
      driverLicenseNumber: json['driver_license_number']?.toString(),
      driverLicenseUrl: json['driver_license_url']?.toString(),
      vehiclePhotoUrl: json['vehicle_photo_url']?.toString(),
    );
  }

  /// JSON từ RPC `get_public_driver_for_order`.
  factory DriverModel.fromPublicProfileJson(Map<String, dynamic> json) {
    return DriverModel.fromJson(json);
  }

  /// Dòng mô tả xe cho UI khách: "Xe máy · Honda Wave · Đỏ".
  String get vehicleSummary {
    final parts = <String>[
      if (vehicleType != null && vehicleType!.trim().isNotEmpty)
        vehicleType!.trim(),
      if (vehicleBrandModel != null && vehicleBrandModel!.trim().isNotEmpty)
        vehicleBrandModel!.trim(),
      if (vehicleColor != null && vehicleColor!.trim().isNotEmpty)
        vehicleColor!.trim(),
    ];
    return parts.join(' · ');
  }

  /// Nhãn rating ngắn cho card.
  String get ratingLabel {
    if (rating == null) {
      return isNewDriver ? 'Tài xế mới' : 'Chưa có đánh giá';
    }
    return rating!.toStringAsFixed(1);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'vehicle_type': vehicleType,
      'license_plate': licensePlate,
      'vehicle_brand_model': vehicleBrandModel,
      'vehicle_color': vehicleColor,
      'is_available': isAvailable,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'updated_at': updatedAt.toIso8601String(),
      'rating': rating,
      'rating_count': ratingCount,
      'total_deliveries': totalDeliveries,
      'approval_status': approvalStatus,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'verified_at': verifiedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'submitted_at': submittedAt?.toIso8601String(),
      'id_card_number': idCardNumber,
      'id_card_front_url': idCardFrontUrl,
      'id_card_back_url': idCardBackUrl,
      'driver_license_number': driverLicenseNumber,
      'driver_license_url': driverLicenseUrl,
      'vehicle_photo_url': vehiclePhotoUrl,
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
