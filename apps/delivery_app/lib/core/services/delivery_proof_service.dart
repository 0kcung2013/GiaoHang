import 'package:image_picker/image_picker.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_proof_model.dart';

class DeliveryProofService {
  DeliveryProofService({SupabaseClient? client, R2MediaClient? r2Client})
    : _supabase = client ?? Supabase.instance.client,
      _r2 = r2Client ?? R2MediaClient.supabase(client: client);

  static const bucketName = 'delivery-proofs';
  static const maxFileSizeBytes = 5 * 1024 * 1024;

  final SupabaseClient _supabase;
  final R2MediaClient _r2;

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

    final storagePath = await _r2.uploadBytes(
      purpose: R2MediaPurpose.deliveryProof,
      bytes: bytes,
      contentType: contentType,
      extension: _extensionFor(image),
      contextId: orderId,
      stage: stage.value,
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
    final proof = DeliveryProofModel.fromJson(response);
    if (stage == DeliveryProofStage.pickup) {
      await confirmPickup(orderId: orderId);
    }
    return proof;
  }

  /// Ảnh chỉ là bằng chứng chuẩn bị; server xác nhận bàn giao mới khóa hủy.
  Future<void> confirmPickup({required String orderId}) async {
    final response = await _supabase.rpc(
      'confirm_driver_pickup',
      params: {'p_order_id': orderId},
    );
    if (response is! String || DateTime.tryParse(response) == null) {
      throw Exception('Server chưa xác nhận nhận hàng. Vui lòng thử lại.');
    }
  }

  Future<String> createSignedUrl({
    required String storagePath,
    int expiresInSeconds = 600,
  }) async {
    if (R2ObjectReference.isR2(storagePath)) {
      return _r2.resolveUrl(storagePath, expiresInSeconds: expiresInSeconds);
    }
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

  String _extensionFor(XFile image) {
    final name = image.name.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return 'jpg';
  }
}
