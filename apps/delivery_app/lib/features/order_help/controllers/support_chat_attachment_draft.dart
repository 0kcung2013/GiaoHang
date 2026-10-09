import 'package:flutter/foundation.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class SupportChatImageDraft {
  SupportChatImageDraft({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  String? objectUri;
}

/// Giữ ảnh đã upload khi gửi tin thất bại để thử lại không upload trùng.
class SupportChatAttachmentDraft {
  SupportChatAttachmentDraft({
    required this.contextId,
    Future<List<XFile>> Function()? pickImages,
    Future<Uint8List> Function(Uint8List)? prepareImage,
    Future<String> Function(Uint8List, String)? uploadImage,
    R2MediaClient? r2Client,
  }) : _pickImages = pickImages ?? _pickGallery,
       _prepareImage = prepareImage ?? _prepare,
       _uploadImage = uploadImage,
       _r2Client = r2Client;

  static const maxBytes = 5 * 1024 * 1024;
  final String contextId;
  final Future<List<XFile>> Function() _pickImages;
  final Future<Uint8List> Function(Uint8List) _prepareImage;
  final Future<String> Function(Uint8List, String)? _uploadImage;
  R2MediaClient? _r2Client;
  final List<SupportChatImageDraft> images = [];

  Future<void> pick() async {
    final files = await _pickImages();
    if (files.isEmpty) return;
    if (images.length + files.length > CaseMessageContent.maxImages) {
      throw const R2MediaException('Mỗi tin nhắn đính kèm tối đa 3 ảnh.');
    }
    final additions = <SupportChatImageDraft>[];
    for (final file in files) {
      if (await file.length() > maxBytes) {
        throw const R2MediaException('Mỗi ảnh không quá 5 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > maxBytes) {
        throw const R2MediaException('Ảnh trống hoặc vượt quá 5 MB.');
      }
      final prepared = await _prepareImage(bytes);
      if (prepared.isEmpty || prepared.length > maxBytes) {
        throw const R2MediaException(
          'Không thể xử lý ảnh trong giới hạn 5 MB.',
        );
      }
      additions.add(SupportChatImageDraft(name: file.name, bytes: prepared));
    }
    images.addAll(additions);
  }

  Future<List<String>> upload() async {
    // Dùng vùng ảnh đơn hàng hiện có thuộc người gửi; CSKH/Admin đã có quyền
    // đọc. Chỉ ghi URI ổn định vào tin nhắn, không đổi Worker hay schema.
    final upload = _uploadImage ?? _uploadToR2;
    for (final image in images) {
      image.objectUri ??= await upload(image.bytes, contextId);
      if (!CaseMessageContent.isSupportedImage(image.objectUri!)) {
        throw const R2MediaException('Đường dẫn ảnh đính kèm không hợp lệ.');
      }
    }
    return [for (final image in images) image.objectUri!];
  }

  void remove(SupportChatImageDraft image) => images.remove(image);
  void clear() => images.clear();

  static Future<List<XFile>> _pickGallery() => ImagePicker().pickMultiImage(
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );

  static Future<Uint8List> _prepare(Uint8List bytes) =>
      compute(_prepareJpeg, bytes);

  Future<String> _uploadToR2(Uint8List bytes, String contextId) =>
      (_r2Client ??= R2MediaClient.supabase()).uploadBytes(
        purpose: R2MediaPurpose.orderCargo,
        bytes: bytes,
        contentType: 'image/jpeg',
        extension: 'jpg',
        contextId: contextId.isEmpty ? 'general' : contextId,
        stage: 'support-chat',
      );
}

Uint8List _prepareJpeg(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const R2MediaException('Tệp đã chọn không phải ảnh hợp lệ.');
  }
  if (decoded == null) {
    throw const R2MediaException('Tệp đã chọn không phải ảnh hợp lệ.');
  }
  final resized = decoded.width > 1600 || decoded.height > 1600
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1600 : null,
          height: decoded.height > decoded.width ? 1600 : null,
        )
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}
