import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverAccountViewData {
  const DriverAccountViewData({
    required this.driverId,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.isAvailable,
    required this.approvalStatus,
    required this.totalDeliveries,
    required this.vehicleType,
    required this.vehicleBrandModel,
    required this.vehicleColor,
    required this.licensePlate,
    required this.hasIdentityCard,
    required this.hasDriverLicense,
    required this.hasVehiclePhoto,
    this.idCardNumber,
    this.idCardFrontUrl,
    this.idCardBackUrl,
    this.driverLicenseNumber,
    this.driverLicenseUrl,
    this.vehiclePhotoUrl,
  });

  final String driverId;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final bool isAvailable;
  final String approvalStatus;
  final int totalDeliveries;
  final String vehicleType;
  final String vehicleBrandModel;
  final String vehicleColor;
  final String licensePlate;
  final bool hasIdentityCard;
  final bool hasDriverLicense;
  final bool hasVehiclePhoto;
  final String? idCardNumber;
  final String? idCardFrontUrl;
  final String? idCardBackUrl;
  final String? driverLicenseNumber;
  final String? driverLicenseUrl;
  final String? vehiclePhotoUrl;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'TX';
    if (parts.length == 1) {
      final value = parts.first;
      final end = value.length < 2 ? value.length : 2;
      return value.substring(0, end).toUpperCase();
    }
    return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
  }

  factory DriverAccountViewData.from({
    required User user,
    DriverModel? driver,
  }) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final email = _firstNonEmpty([driver?.email, user.email]) ?? '';
    final metadataName = _firstNonEmpty([
      metadata['full_name']?.toString(),
      metadata['name']?.toString(),
    ]);
    final emailName = email.contains('@') ? email.split('@').first : email;

    return DriverAccountViewData(
      driverId: driver?.id ?? user.id,
      name:
          _firstNonEmpty([driver?.fullName, metadataName, emailName]) ??
          'Tài xế',
      email: email,
      phone: _firstNonEmpty([driver?.phone, user.phone]) ?? '',
      avatarUrl: _firstNonEmpty([
        driver?.avatarUrl,
        metadata['avatar_url']?.toString(),
        metadata['picture']?.toString(),
      ]),
      isAvailable: driver?.isAvailable ?? false,
      approvalStatus: driver?.approvalStatus ?? 'pending',
      totalDeliveries: driver?.totalDeliveries ?? 0,
      vehicleType: driver?.vehicleType?.trim() ?? '',
      vehicleBrandModel: driver?.vehicleBrandModel?.trim() ?? '',
      vehicleColor: driver?.vehicleColor?.trim() ?? '',
      licensePlate: driver?.licensePlate?.trim() ?? '',
      hasIdentityCard:
          _hasValue(driver?.idCardNumber) ||
          _hasValue(driver?.idCardFrontUrl) ||
          _hasValue(driver?.idCardBackUrl),
      hasDriverLicense:
          _hasValue(driver?.driverLicenseNumber) ||
          _hasValue(driver?.driverLicenseUrl),
      hasVehiclePhoto: _hasValue(driver?.vehiclePhotoUrl),
      idCardNumber: _nonEmpty(driver?.idCardNumber),
      idCardFrontUrl: _nonEmpty(driver?.idCardFrontUrl),
      idCardBackUrl: _nonEmpty(driver?.idCardBackUrl),
      driverLicenseNumber: _nonEmpty(driver?.driverLicenseNumber),
      driverLicenseUrl: _nonEmpty(driver?.driverLicenseUrl),
      vehiclePhotoUrl: _nonEmpty(driver?.vehiclePhotoUrl),
    );
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  static bool _hasValue(String? value) => value?.trim().isNotEmpty == true;

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
