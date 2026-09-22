import 'package:flutter/foundation.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload ảnh KYC / avatar tài xế lên bucket `driver-kyc`.
class DriverKycStorageService {
  DriverKycStorageService({SupabaseClient? client, R2MediaClient? r2Client})
    : _r2 = r2Client ?? R2MediaClient.supabase(client: client);

  final R2MediaClient _r2;

  Future<String> uploadDriverImage({
    required String userId,
    required XFile image,
    required String kind,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image);

    debugPrint(
      '[DriverKyc] upload start target=r2 user=$userId kind=$kind '
      'size=${bytes.length}',
    );

    final objectUri = await _r2.uploadBytes(
      purpose: kind == 'avatar'
          ? R2MediaPurpose.avatar
          : R2MediaPurpose.driverKyc,
      bytes: bytes,
      contentType: _contentTypeFor(extension),
      extension: extension,
      stage: kind,
    );
    debugPrint('[DriverKyc] upload ok object=$objectUri');
    return objectUri;
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
