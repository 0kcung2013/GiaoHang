import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

String driverProfileChangeFieldLabel(DriverProfileChangeField field) {
  return switch (field) {
    DriverProfileChangeField.fullName => 'Họ và tên',
    DriverProfileChangeField.email => 'Email',
    DriverProfileChangeField.phone => 'Số điện thoại',
    DriverProfileChangeField.avatar => 'Ảnh đại diện',
    DriverProfileChangeField.vehicleType => 'Loại phương tiện',
    DriverProfileChangeField.vehicleBrandModel => 'Hãng và dòng xe',
    DriverProfileChangeField.vehicleColor => 'Màu xe',
    DriverProfileChangeField.licensePlate => 'Biển số xe',
    DriverProfileChangeField.idCardNumber => 'Số căn cước công dân',
    DriverProfileChangeField.idCardFront => 'Ảnh mặt trước căn cước',
    DriverProfileChangeField.idCardBack => 'Ảnh mặt sau căn cước',
    DriverProfileChangeField.driverLicenseNumber => 'Số giấy phép lái xe',
    DriverProfileChangeField.driverLicense => 'Ảnh giấy phép lái xe',
    DriverProfileChangeField.vehiclePhoto => 'Ảnh phương tiện',
  };
}

IconData driverProfileChangeFieldIcon(DriverProfileChangeField field) {
  return switch (field) {
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
}

bool isDriverProfileFileField(DriverProfileChangeField field) => const {
  DriverProfileChangeField.avatar,
  DriverProfileChangeField.idCardFront,
  DriverProfileChangeField.idCardBack,
  DriverProfileChangeField.driverLicense,
  DriverProfileChangeField.vehiclePhoto,
}.contains(field);

String driverProfileChangeDisplayValue(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? 'Chưa cập nhật' : text;
}

String driverProfileChangeStatusLabel(DriverProfileChangeStatus status) {
  return switch (status) {
    DriverProfileChangeStatus.draft => 'Bản nháp',
    DriverProfileChangeStatus.pending => 'Đang chờ Admin duyệt',
    DriverProfileChangeStatus.applying => 'Đang áp dụng thay đổi',
    DriverProfileChangeStatus.approved => 'Đã được Admin duyệt',
    DriverProfileChangeStatus.rejected => 'Admin đã từ chối',
    DriverProfileChangeStatus.cancelled => 'Đã hủy yêu cầu',
    DriverProfileChangeStatus.conflicted => 'Hồ sơ đã thay đổi',
  };
}
