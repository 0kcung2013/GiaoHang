import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> pickOrderCargoImage(ImageSource source) async {
  try {
    return await ImagePicker().pickImage(
      source: kIsWeb ? ImageSource.gallery : source,
      maxWidth: 1600,
      imageQuality: 82,
    );
  } on PlatformException {
    throw const OrderCargoPickerException(
      'Không thể mở thư viện ảnh. Vui lòng kiểm tra quyền truy cập ảnh.',
    );
  } catch (_) {
    throw const OrderCargoPickerException(
      'Không thể chọn ảnh. Vui lòng thử lại.',
    );
  }
}

class OrderCargoPickerException implements Exception {
  const OrderCargoPickerException(this.message);

  final String message;

  @override
  String toString() => message;
}
