import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_proof_model.dart';

class DeliveryProofService {
  DeliveryProofService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const bucketName = 'delivery-proofs';
  static const maxFileSizeBytes = 5 * 1024 * 1024;

  final SupabaseClient _supabase;

  Future<DeliveryProofModel> submitProof({
    required String orderId,
    required String driverId,
    required DeliveryProofStage stage,
    required XFile image,
    DateTime? capturedAt,
    double? capturedLat,
    double? capturedLng,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId != driverId) {
      throw Exception('Phiên tài xế không hợp lệ. Vui lòng đăng nhập lại.');
    }

    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Ảnh xác nhận bị trống. Vui lòng chụp lại.');
    }
    if (bytes.length > maxFileSizeBytes) {
      throw Exception('Ảnh xác nhận phải nhỏ hơn 5 MB.');
    }

    final contentType = _contentTypeFor(image);
    if (contentType == null) {
      throw Exception('Chỉ hỗ trợ ảnh JPG, PNG hoặc WebP.');
    }

    final storagePath = '$driverId/$orderId/${stage.value}';
    await _supabase.storage
        .from(bucketName)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            cacheControl: '3600',
            upsert: true,
          ),
        );

    final payload = <String, dynamic>{
      'order_id': orderId,
      'driver_id': driverId,
      'stage': stage.value,
      'storage_path': storagePath,
      'captured_at': (capturedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'captured_lat': capturedLat,
      'captured_lng': capturedLng,
    };

    final response = await _supabase
        .from('order_delivery_proofs')
        .upsert(payload, onConflict: 'order_id,stage')
        .select()
        .single();
    return DeliveryProofModel.fromJson(response);
  }

  Future<String> createSignedUrl({
    required String storagePath,
    int expiresInSeconds = 600,
  }) {
    return _supabase.storage
        .from(bucketName)
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  Future<List<DeliveryProofImageModel>> getProofsForOrder({
    required String orderId,
    int signedUrlExpiresInSeconds = 3600,
  }) async {
    try {
      final response = await _supabase
          .from('order_delivery_proofs')
          .select()
          .eq('order_id', orderId)
          .order('captured_at');
      final proofs = response.map(DeliveryProofModel.fromJson).toList();

      return Future.wait(
        proofs.map((proof) async {
          final imageUrl = await createSignedUrl(
            storagePath: proof.storagePath,
            expiresInSeconds: signedUrlExpiresInSeconds,
          );
          return DeliveryProofImageModel(proof: proof, imageUrl: imageUrl);
        }),
      );
    } catch (error) {
      throw Exception('Không thể tải ảnh bàn giao: $error');
    }
  }

  String? _contentTypeFor(XFile image) {
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp') {
      return mimeType;
    }

    final name = image.name.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return null;
  }
}
