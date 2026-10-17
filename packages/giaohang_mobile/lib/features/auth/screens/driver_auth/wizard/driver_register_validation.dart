import '../driver_auth_strings.dart';
import 'driver_register_data.dart';

enum DriverRegisterField {
  email,
  password,
  name,
  phone,
  avatar,
  model,
  color,
  plate,
  idNumber,
  idFront,
  idBack,
  licenseNumber,
  licensePhoto,
  vehiclePhoto,
}

class DriverRegisterIssue {
  const DriverRegisterIssue(this.field, this.message);
  final DriverRegisterField field;
  final String message;

  String? forField(DriverRegisterField value) =>
      field == value ? message : null;
}

/// The existing five-step validation rules, independent of presentation.
DriverRegisterIssue? validateDriverRegisterStep(
  int step,
  DriverRegisterData data,
) {
  switch (step) {
    case 0:
      if (!data.email.contains('@') || !data.email.contains('.')) {
        return const DriverRegisterIssue(
          DriverRegisterField.email,
          DriverAuthStrings.invalidEmail,
        );
      }
      if (data.password.length < 6) {
        return const DriverRegisterIssue(
          DriverRegisterField.password,
          DriverAuthStrings.shortPassword,
        );
      }
    case 1:
      if (data.fullName.trim().isEmpty) {
        return const DriverRegisterIssue(
          DriverRegisterField.name,
          DriverAuthStrings.missingName,
        );
      }
      if (data.phone.trim().length < 10) {
        return const DriverRegisterIssue(
          DriverRegisterField.phone,
          DriverAuthStrings.invalidPhone,
        );
      }
      if (data.avatarFile == null) {
        return const DriverRegisterIssue(
          DriverRegisterField.avatar,
          DriverAuthStrings.missingAvatar,
        );
      }
    case 2:
      if (data.vehicleBrandModel.trim().isEmpty) {
        return const DriverRegisterIssue(
          DriverRegisterField.model,
          DriverAuthStrings.missingModel,
        );
      }
      if (data.vehicleColor.trim().isEmpty) {
        return const DriverRegisterIssue(
          DriverRegisterField.color,
          DriverAuthStrings.missingColor,
        );
      }
      if (data.licensePlate.trim().isEmpty) {
        return const DriverRegisterIssue(
          DriverRegisterField.plate,
          DriverAuthStrings.missingPlate,
        );
      }
    case 3:
      if (data.idCardNumber.trim().length < 9) {
        return const DriverRegisterIssue(
          DriverRegisterField.idNumber,
          DriverAuthStrings.invalidId,
        );
      }
      if (data.idCardFrontFile == null) {
        return const DriverRegisterIssue(
          DriverRegisterField.idFront,
          DriverAuthStrings.missingIdPhotos,
        );
      }
      if (data.idCardBackFile == null) {
        return const DriverRegisterIssue(
          DriverRegisterField.idBack,
          DriverAuthStrings.missingIdPhotos,
        );
      }
      if (data.driverLicenseNumber.trim().isEmpty) {
        return const DriverRegisterIssue(
          DriverRegisterField.licenseNumber,
          DriverAuthStrings.missingLicenseNumber,
        );
      }
      if (data.driverLicenseFile == null) {
        return const DriverRegisterIssue(
          DriverRegisterField.licensePhoto,
          DriverAuthStrings.missingLicensePhoto,
        );
      }
      if (data.vehiclePhotoFile == null) {
        return const DriverRegisterIssue(
          DriverRegisterField.vehiclePhoto,
          DriverAuthStrings.missingVehiclePhoto,
        );
      }
  }
  return null;
}
