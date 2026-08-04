import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload ảnh KYC / avatar tài xế lên bucket `driver-kyc`.
class DriverKycStorageService {
  DriverKycStorageService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const bucketName = 'driver-kyc';

  final SupabaseClient _supabase;

  Future<String> uploadDriverImage({
    required String userId,
    required XFile image,
    required String kind,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image);
    final path =
        '$userId/${kind}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    debugPrint(
      '[DriverKyc] upload start bucket=$bucketName path=$path size=${bytes.length}',
    );

    await _supabase.storage
        .from(bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(extension),
            upsert: true,
          ),
        );

    final url = _supabase.storage.from(bucketName).getPublicUrl(path);
    debugPrint('[DriverKyc] upload ok url=$url');
    return url;
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
