import 'package:flutter/foundation.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../utils/risk_photo_processor.dart';

const _evidenceBucket = 'risk-report-evidence';
const _requestTimeout = Duration(seconds: 20);
const _photoProcessingTimeout = Duration(seconds: 30);

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
  Future<RiskReportSubmissionResult> submit(
    ParticipantRiskReportDraft draft, {
    RiskReportProgressCallback? onProgress,
  });
}

enum RiskReportSubmissionPhase {
  checkingDuplicate,
  processingImages,
  uploadingImages,
  sendingReport,
}

typedef RiskReportProgressCallback =
    void Function(RiskReportSubmissionPhase phase);

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
typedef _CheckDuplicate =
    Future<bool> Function(String orderId, RiskCategory category);
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
        checkDuplicate: (orderId, category) async {
          return (client ?? Supabase.instance.client).rpc<bool>(
            'has_active_participant_risk_report',
            params: {
              'p_order_id': orderId,
              'p_category': category.databaseValue,
            },
          );
        },
        processPhoto: prepareRiskPhotoForUpload,
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
    required Future<bool> Function(String, RiskCategory) checkDuplicate,
    required Future<Uint8List> Function(Uint8List bytes) processPhoto,
    required Future<void> Function(String path, Uint8List bytes) upload,
    required Future<void> Function(List<String> paths) remove,
    required Future<dynamic> Function(Map<String, dynamic> params) invokeCreate,
  }) : this._(
         currentUserId: currentUserId,
         createId: createId,
         checkDuplicate: checkDuplicate,
         processPhoto: processPhoto,
         upload: upload,
         remove: remove,
         invokeCreate: invokeCreate,
       );

  SupabaseParticipantRiskReportRepository._({
    required _CurrentUserId currentUserId,
    required _CreateId createId,
    required _CheckDuplicate checkDuplicate,
    required _ProcessPhoto processPhoto,
    required _UploadEvidence upload,
    required _RemoveEvidence remove,
    required _InvokeCreate invokeCreate,
  }) : _currentUserId = currentUserId,
       _createId = createId,
       _checkDuplicate = checkDuplicate,
       _processPhoto = processPhoto,
       _upload = upload,
       _remove = remove,
       _invokeCreate = invokeCreate;

  final _CurrentUserId _currentUserId;
  final _CreateId _createId;
  final _CheckDuplicate _checkDuplicate;
  final _ProcessPhoto _processPhoto;
  final _UploadEvidence _upload;
  final _RemoveEvidence _remove;
  final _InvokeCreate _invokeCreate;

  @override
  Future<RiskReportSubmissionResult> submit(
    ParticipantRiskReportDraft draft, {
    RiskReportProgressCallback? onProgress,
  }) async {
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

    onProgress?.call(RiskReportSubmissionPhase.checkingDuplicate);
    await Future<void>.delayed(Duration.zero);
    try {
      if (await _checkDuplicate(
        draft.orderId,
        draft.category,
      ).timeout(_requestTimeout)) {
        throw const RiskReportRepositoryException(
          code: RiskReportErrorCode.duplicate,
          userMessage: 'Sự cố này đã được báo cáo và đang được CSKH xử lý.',
        );
      }
    } catch (error) {
      throw _mapError(error);
    }

    final reportId = _createId();
    var preparedPhotos = <_PreparedRiskPhoto>[];
    if (draft.photos.isNotEmpty) {
      onProgress?.call(RiskReportSubmissionPhase.processingImages);
      await Future<void>.delayed(Duration.zero);
      try {
        preparedPhotos = await _mapWithConcurrency(
          draft.photos,
          limit: 2,
          convert: (photo, _) async => _PreparedRiskPhoto(
            path: '$userId/$reportId/${_createId()}.jpg',
            bytes: await _processPhoto(
              photo.bytes,
            ).timeout(_photoProcessingTimeout),
          ),
        );
      } catch (error) {
        if (error is RiskReportRepositoryException) rethrow;
        throw const RiskReportRepositoryException(
          code: RiskReportErrorCode.validation,
          userMessage: 'Không thể xử lý ảnh đã chọn. Vui lòng chọn ảnh khác.',
        );
      }
    }

    final uploadedPaths = <String>[];
    if (preparedPhotos.isNotEmpty) {
      onProgress?.call(RiskReportSubmissionPhase.uploadingImages);
      await Future<void>.delayed(Duration.zero);
      try {
        await _mapWithConcurrency(
          preparedPhotos,
          limit: 2,
          convert: (photo, _) async {
            await _upload(photo.path, photo.bytes).timeout(_requestTimeout);
            uploadedPaths.add(photo.path);
            return photo.path;
          },
        );
      } catch (_) {
        await _bestEffortCleanup(uploadedPaths);
        throw const RiskReportRepositoryException(
          code: RiskReportErrorCode.uploadFailed,
          userMessage: 'Không thể tải ảnh lên. Vui lòng thử lại.',
        );
      }
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
    onProgress?.call(RiskReportSubmissionPhase.sendingReport);
    await Future<void>.delayed(Duration.zero);
    try {
      final response = await _invokeCreate(
        submission.toRpcJson(),
      ).timeout(_requestTimeout);
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
      if (error.message.contains('DRIVER_REPORT_AFTER_DELIVERY')) {
        return const RiskReportRepositoryException(
          code: RiskReportErrorCode.validation,
          userMessage:
              'Đơn đã xác nhận giao thành công. Tài xế chịu trách nhiệm với lần xác nhận này và không thể báo giao thất bại.',
        );
      }
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
}

class _PreparedRiskPhoto {
  const _PreparedRiskPhoto({required this.path, required this.bytes});

  final String path;
  final Uint8List bytes;
}

Future<List<R>> _mapWithConcurrency<T, R>(
  List<T> items, {
  required int limit,
  required Future<R> Function(T item, int index) convert,
}) async {
  if (items.isEmpty) return <R>[];

  final results = List<R?>.filled(items.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (nextIndex < items.length) {
      final index = nextIndex;
      nextIndex += 1;
      results[index] = await convert(items[index], index);
    }
  }

  final workerCount = items.length < limit ? items.length : limit;
  await Future.wait(List.generate(workerCount, (_) => worker()));
  return results.cast<R>();
}
