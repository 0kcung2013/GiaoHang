import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

String adminDriverProfileFieldLabel(DriverProfileChangeField field) =>
    switch (field) {
      DriverProfileChangeField.fullName => 'Họ và tên',
      DriverProfileChangeField.email => 'Email',
      DriverProfileChangeField.phone => 'Số điện thoại',
      DriverProfileChangeField.avatar => 'Ảnh đại diện',
      DriverProfileChangeField.vehicleType => 'Loại phương tiện',
      DriverProfileChangeField.vehicleBrandModel => 'Hãng và dòng xe',
      DriverProfileChangeField.vehicleColor => 'Màu xe',
      DriverProfileChangeField.licensePlate => 'Biển số xe',
      DriverProfileChangeField.idCardNumber => 'Số căn cước công dân',
      DriverProfileChangeField.idCardFront => 'Mặt trước căn cước',
      DriverProfileChangeField.idCardBack => 'Mặt sau căn cước',
      DriverProfileChangeField.driverLicenseNumber => 'Số giấy phép lái xe',
      DriverProfileChangeField.driverLicense => 'Ảnh giấy phép lái xe',
      DriverProfileChangeField.vehiclePhoto => 'Ảnh phương tiện',
    };

IconData adminDriverProfileFieldIcon(DriverProfileChangeField field) =>
    switch (field) {
      DriverProfileChangeField.fullName => Icons.person_outline_rounded,
      DriverProfileChangeField.email => Icons.alternate_email_rounded,
      DriverProfileChangeField.phone => Icons.phone_outlined,
      DriverProfileChangeField.avatar => Icons.account_circle_outlined,
      DriverProfileChangeField.vehicleType => Icons.category_outlined,
      DriverProfileChangeField.vehicleBrandModel => Icons.two_wheeler_rounded,
      DriverProfileChangeField.vehicleColor => Icons.palette_outlined,
      DriverProfileChangeField.licensePlate => Icons.pin_outlined,
      DriverProfileChangeField.idCardNumber => Icons.badge_outlined,
      DriverProfileChangeField.idCardFront ||
      DriverProfileChangeField.idCardBack => Icons.credit_card_rounded,
      DriverProfileChangeField.driverLicenseNumber =>
        Icons.confirmation_number_outlined,
      DriverProfileChangeField.driverLicense => Icons.card_membership_outlined,
      DriverProfileChangeField.vehiclePhoto => Icons.photo_camera_outlined,
    };

bool isAdminDriverProfileMediaField(DriverProfileChangeField field) => const {
  DriverProfileChangeField.avatar,
  DriverProfileChangeField.idCardFront,
  DriverProfileChangeField.idCardBack,
  DriverProfileChangeField.driverLicense,
  DriverProfileChangeField.vehiclePhoto,
}.contains(field);

String adminDriverProfileDisplayValue(
  DriverProfileChangeField field,
  Object? value,
) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return 'Chưa cập nhật';
  if (field == DriverProfileChangeField.idCardNumber ||
      field == DriverProfileChangeField.driverLicenseNumber) {
    if (text.length <= 4) return List.filled(text.length, '•').join();
    return '${List.filled(text.length - 4, '•').join()}${text.substring(text.length - 4)}';
  }
  return text;
}
