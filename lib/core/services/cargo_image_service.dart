import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CargoImageService {
  CargoImageService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const bucketName = 'order-cargo';
  static const _debugTag = '[CargoImagePickerDebug]';

  final SupabaseClient _supabase;

  Future<String> uploadOrderCargoImage({
    required String userId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image);
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    debugPrint(
      '$_debugTag service upload start bucket=$bucketName path=$path '
      'name=${image.name} size=${bytes.length}',
    );

    await _supabase.storage
        .from(bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(extension),
            upsert: false,
          ),
        );

    final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(path);
    debugPrint('$_debugTag service upload success url=$publicUrl');
    return publicUrl;
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
