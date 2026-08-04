import 'package:image_picker/image_picker.dart';

/// State form wizard đăng ký tài xế (5 bước).
class DriverRegisterData {
  String email = '';
  String password = '';
  String fullName = '';
  String phone = '';
  String vehicleType = 'Xe máy';
  String vehicleBrandModel = '';
  String vehicleColor = '';
  String licensePlate = '';
  String idCardNumber = '';
  String driverLicenseNumber = '';

  XFile? avatarFile;
  XFile? idCardFrontFile;
  XFile? idCardBackFile;
  XFile? driverLicenseFile;
  XFile? vehiclePhotoFile;

  static const vehicleTypes = ['Xe máy', 'Ô tô con', 'Xe tải'];
}
