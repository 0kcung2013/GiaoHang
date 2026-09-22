import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CargoImageService {
  CargoImageService({SupabaseClient? client, R2MediaClient? r2Client})
    : _r2 = r2Client ?? R2MediaClient.supabase(client: client);

  static const _debugTag = '[CargoImagePickerDebug]';

  final R2MediaClient _r2;

  Future<String> uploadOrderCargoImage({
    required String userId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image);

    debugPrint(
      '$_debugTag service upload start target=r2 '
      'user=$userId name=${image.name} size=${bytes.length}',
    );

    try {
      final objectUri = await _r2.uploadBytes(
        purpose: R2MediaPurpose.orderCargo,
        bytes: bytes,
        contentType: _contentTypeFor(extension),
        extension: extension,
      );
      debugPrint('$_debugTag service upload success object=$objectUri');
      return objectUri;
    } catch (error, stackTrace) {
      debugPrint('$_debugTag service upload failed error=$error\n$stackTrace');
      rethrow;
    }
  }

  String _extensionFor(XFile image) {
    final name = image.name.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
