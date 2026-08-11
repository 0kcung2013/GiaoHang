import 'dart:typed_data';

import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:image/image.dart' as image_lib;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _evidenceBucket = 'risk-report-evidence';

class RiskPhotoInput {
  const RiskPhotoInput({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class ParticipantRiskReportDraft {
  const ParticipantRiskReportDraft({
    required this.orderId,
    required this.category,
    required this.description,
    this.photos = const [],
    this.latitude,
    this.longitude,
    this.locationCapturedAt,
    this.messageIds = const [],
  });

  final String orderId;
  final RiskCategory category;
  final String description;
  final List<RiskPhotoInput> photos;
  final double? latitude;
  final double? longitude;
  final DateTime? locationCapturedAt;
  final List<String> messageIds;
}

abstract interface class ParticipantRiskReportRepository {
  Future<RiskReportSubmissionResult> submit(ParticipantRiskReportDraft draft);
}

enum RiskReportErrorCode {
  unauthorized,
  duplicate,
  validation,
  uploadFailed,
  network,
  unknown,
}

class RiskReportRepositoryException implements Exception {
  const RiskReportRepositoryException({
    required this.code,
    required this.userMessage,
  });

  final RiskReportErrorCode code;
  final String userMessage;

  @override
  String toString() => userMessage;
}

typedef _CurrentUserId = String? Function();
typedef _CreateId = String Function();
typedef _ProcessPhoto = Future<Uint8List> Function(Uint8List bytes);
typedef _UploadEvidence = Future<void> Function(String path, Uint8List bytes);
typedef _RemoveEvidence = Future<void> Function(List<String> paths);
typedef _InvokeCreate = Future<dynamic> Function(Map<String, dynamic> params);

class SupabaseParticipantRiskReportRepository
    implements ParticipantRiskReportRepository {
  SupabaseParticipantRiskReportRepository({SupabaseClient? client})
    : this._(
        currentUserId: () =>
            (client ?? Supabase.instance.client).auth.currentUser?.id,
        createId: const Uuid().v4,
        processPhoto: _compressPhoto,
        upload: (path, bytes) async {
          await (client ?? Supabase.instance.client).storage
              .from(_evidenceBucket)
              .uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: false,
                ),
              );
        },
        remove: (paths) async {
          if (paths.isNotEmpty) {
            await (client ?? Supabase.instance.client).storage
                .from(_evidenceBucket)
                .remove(paths);
          }
        },
        invokeCreate: (params) => (client ?? Supabase.instance.client).rpc(
          'create_participant_risk_report',
          params: params,
        ),
      );

  SupabaseParticipantRiskReportRepository.test({
    required String? Function() currentUserId,
    required String Function() createId,
    required Future<Uint8List> Function(Uint8List bytes) processPhoto,
    required Future<void> Function(String path, Uint8List bytes) upload,
    required Future<void> Function(List<String> paths) remove,
    required Future<dynamic> Function(Map<String, dynamic> params) invokeCreate,
  }) : this._(
         currentUserId: currentUserId,
         createId: createId,
         processPhoto: processPhoto,
         upload: upload,
         remove: remove,
         invokeCreate: invokeCreate,
       );

  SupabaseParticipantRiskReportRepository._({
    required _CurrentUserId currentUserId,
    required _CreateId createId,
    required _ProcessPhoto processPhoto,
    required _UploadEvidence upload,
    required _RemoveEvidence remove,
    required _InvokeCreate invokeCreate,
  }) : _currentUserId = currentUserId,
       _createId = createId,
       _processPhoto = processPhoto,
       _upload = upload,
       _remove = remove,
       _invokeCreate = invokeCreate;

  final _CurrentUserId _currentUserId;
  final _CreateId _createId;
  final _ProcessPhoto _processPhoto;
  final _UploadEvidence _upload;
  final _RemoveEvidence _remove;
  final _InvokeCreate _invokeCreate;

  @override
  Future<RiskReportSubmissionResult> submit(
    ParticipantRiskReportDraft draft,
  ) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw const RiskReportRepositoryException(
        code: RiskReportErrorCode.unauthorized,
        userMessage: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    if (draft.photos.length > 5) {
      throw const RiskReportRepositoryException(
        code: RiskReportErrorCode.validation,
        userMessage: 'Bạn chỉ có thể gửi tối đa 5 ảnh.',
      );
    }

    final reportId = _createId();
    final uploadedPaths = <String>[];
    try {
      for (final photo in draft.photos) {
        final fileId = _createId();
        final path = '$userId/$reportId/$fileId.jpg';
        final bytes = await _processPhoto(photo.bytes);
        await _upload(path, bytes);
        uploadedPaths.add(path);
      }
    } catch (_) {
      await _bestEffortCleanup(uploadedPaths);
      throw const RiskReportRepositoryException(
        code: RiskReportErrorCode.uploadFailed,
        userMessage: 'Không thể tải ảnh lên. Vui lòng thử lại.',
      );
    }

    final submission = RiskReportSubmission(
      reportId: reportId,
      orderId: draft.orderId,
      category: draft.category,
      description: draft.description,
      photoPaths: uploadedPaths,
      latitude: draft.latitude,
      longitude: draft.longitude,
      locationCapturedAt: draft.locationCapturedAt,
      messageIds: draft.messageIds,
    );
    try {
      final response = await _invokeCreate(submission.toRpcJson());
      return RiskReportSubmissionResult.fromJson(_firstRow(response));
    } catch (error) {
      await _bestEffortCleanup(uploadedPaths);
      throw _mapError(error);
    }
  }

  Future<void> _bestEffortCleanup(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _remove(paths);
    } catch (_) {
      // The bucket policy still allows later cleanup of unregistered own files.
    }
  }

  static Map<String, dynamic> _firstRow(dynamic response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    throw const RiskReportRepositoryException(
      code: RiskReportErrorCode.unknown,
      userMessage: 'Phản hồi từ hệ thống không hợp lệ.',
    );
  }

  static RiskReportRepositoryException _mapError(Object error) {
    if (error is RiskReportRepositoryException) return error;
    if (error is PostgrestException) {
      return switch (error.code) {
        '23505' => const RiskReportRepositoryException(
          code: RiskReportErrorCode.duplicate,
          userMessage: 'Sự cố này đã được báo cáo và đang được xử lý.',
        ),
        '42501' => const RiskReportRepositoryException(
          code: RiskReportErrorCode.unauthorized,
          userMessage: 'Bạn không có quyền báo cáo sự cố cho đơn này.',
        ),
        '22023' || '23514' => const RiskReportRepositoryException(
          code: RiskReportErrorCode.validation,
          userMessage: 'Thông tin báo cáo chưa hợp lệ. Vui lòng kiểm tra lại.',
        ),
        _ => const RiskReportRepositoryException(
          code: RiskReportErrorCode.network,
          userMessage: 'Chưa thể gửi báo cáo. Vui lòng thử lại.',
        ),
      };
    }
    return const RiskReportRepositoryException(
      code: RiskReportErrorCode.network,
      userMessage: 'Chưa thể gửi báo cáo. Vui lòng thử lại.',
    );
  }

  static Future<Uint8List> _compressPhoto(Uint8List bytes) async {
    final decoded = image_lib.decodeImage(bytes);
    if (decoded == null) {
      throw const RiskReportRepositoryException(
        code: RiskReportErrorCode.validation,
        userMessage: 'Ảnh đã chọn không hợp lệ.',
      );
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
}
