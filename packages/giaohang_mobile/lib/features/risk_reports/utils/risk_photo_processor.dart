import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;

typedef RiskPhotoNativeProcessor = Future<Uint8List> Function(Uint8List bytes);

/// ImagePicker đã resize ảnh trước khi trả bytes. Trên Web không decode lại bằng
/// package:image vì `compute` chạy trên main event loop và có thể khóa UI lâu.
Future<Uint8List> prepareRiskPhotoForUpload(
  Uint8List bytes, {
  bool? isWeb,
  RiskPhotoNativeProcessor? nativeProcessor,
}) async {
  if (isWeb ?? kIsWeb) return bytes;
  return (nativeProcessor ?? _compressRiskPhotoNative)(bytes);
}

Future<Uint8List> _compressRiskPhotoNative(Uint8List bytes) {
  return compute(_compressRiskPhoto, bytes);
}

Uint8List _compressRiskPhoto(Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Invalid risk evidence image.');
  }
  final resized = decoded.width > 1600 || decoded.height > 1600
      ? image_lib.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1600 : null,
          height: decoded.height > decoded.width ? 1600 : null,
        )
      : decoded;
  return Uint8List.fromList(image_lib.encodeJpg(resized, quality: 82));
}
