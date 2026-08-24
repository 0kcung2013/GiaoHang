import 'package:flutter/foundation.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class DriverProfileChangeGateway {
  Future<Object?> rpc(
    String function, {
    Map<String, Object?> params = const {},
  });

  Future<List<Map<String, dynamic>>> fetchLatestRows();

  Stream<List<Map<String, dynamic>>> watchLatestRows();

  Future<String> upload({
    required String path,
    required List<int> bytes,
    required String contentType,
  });

  Future<void> remove(List<String> paths);
}

abstract interface class DriverProfileChangeRepository {
  Future<DriverProfileChangeRequest?> fetchLatest();

  Stream<DriverProfileChangeRequest?> watchLatest();

  Future<DriverProfileChangeRequest> createDraft();

  Future<DriverProfileChangeRequest> submit({
    required String requestId,
    required Map<DriverProfileChangeField, Object?> changes,
    required String reason,
  });

  Future<void> cancel(String requestId);

  Future<String> uploadDraftFile({
    required String requestId,
    required DriverProfileChangeField field,
    required List<int> bytes,
    required String extension,
    required String contentType,
  });
}

class SupabaseDriverProfileChangeRepository
    implements DriverProfileChangeRepository {
  SupabaseDriverProfileChangeRepository({
    DriverProfileChangeGateway? gateway,
    String? Function()? currentUserId,
  }) : _gateway = gateway ?? SupabaseDriverProfileChangeGateway(),
       _currentUserId =
           currentUserId ??
           (() => Supabase.instance.client.auth.currentUser?.id);

  final DriverProfileChangeGateway _gateway;
  final String? Function() _currentUserId;
  final Map<String, Set<String>> _uploadedPathsByRequest = {};

  @override
  Future<DriverProfileChangeRequest?> fetchLatest() async {
    try {
      final rows = await _gateway.fetchLatestRows();
      return rows.isEmpty
          ? null
          : DriverProfileChangeRequest.fromJson(rows.first);
    } on PostgrestException catch (error) {
      throw DriverProfileChangeException.fromPostgrest(error);
    }
  }

  @override
  Stream<DriverProfileChangeRequest?> watchLatest() {
    return _gateway.watchLatestRows().map(
      (rows) =>
          rows.isEmpty ? null : DriverProfileChangeRequest.fromJson(rows.first),
    );
  }

  @override
  Future<DriverProfileChangeRequest> createDraft() async {
    try {
      final response = await _gateway.rpc('create_driver_profile_change_draft');
      return _requestFromResponse(response);
    } on PostgrestException catch (error) {
      throw DriverProfileChangeException.fromPostgrest(error);
    }
  }

  @override
  Future<DriverProfileChangeRequest> submit({
    required String requestId,
    required Map<DriverProfileChangeField, Object?> changes,
    required String reason,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.length < 3) {
      throw const DriverProfileChangeException(
        'Vui lòng nhập lý do thay đổi ít nhất 3 ký tự.',
      );
    }
    final normalizedChanges = <String, Object?>{
      for (final entry in changes.entries)
        entry.key.requestKey: _normalizeValue(entry.key, entry.value),
    };
    normalizedChanges.removeWhere((_, value) => value == null);
    if (normalizedChanges.isEmpty) {
      throw const DriverProfileChangeException(
        'Vui lòng chọn ít nhất một thông tin cần thay đổi.',
      );
    }

    try {
      final response = await _gateway.rpc(
        'submit_driver_profile_change_request',
        params: {
          'p_request_id': requestId,
          'p_requested_changes': normalizedChanges,
          'p_reason': normalizedReason,
        },
      );
      return _requestFromResponse(response);
    } on PostgrestException catch (error) {
      throw DriverProfileChangeException.fromPostgrest(error);
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    DriverProfileChangeRequest? current;
    try {
      current = await fetchLatest();
      final paths = _ownedFilePaths(requestId, current);
      if (current?.id == requestId &&
          current?.status == DriverProfileChangeStatus.draft) {
        await _removeBestEffort(paths);
      }

      final response = await _gateway.rpc(
        'cancel_driver_profile_change_request',
        params: {'p_request_id': requestId},
      );
      final cancelled = _requestFromResponse(response);
      if (cancelled.status != DriverProfileChangeStatus.draft) {
        await _removeBestEffort(_ownedFilePaths(requestId, cancelled));
      }
      _uploadedPathsByRequest.remove(requestId);
    } on PostgrestException catch (error) {
      throw DriverProfileChangeException.fromPostgrest(error);
    }
  }

  @override
  Future<String> uploadDraftFile({
    required String requestId,
    required DriverProfileChangeField field,
    required List<int> bytes,
    required String extension,
    required String contentType,
  }) async {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      throw const DriverProfileChangeException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    final fileName = _fileName(field);
    final normalizedExtension = extension.trim().toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(normalizedExtension)) {
      throw const DriverProfileChangeException(
        'Ảnh phải có định dạng JPG, PNG hoặc WebP.',
      );
    }
    if (bytes.isEmpty) {
      throw const DriverProfileChangeException('Tệp ảnh đang trống.');
    }

    final path = '$userId/$requestId/$fileName.$normalizedExtension';
    try {
      final uploadedPath = await _gateway.upload(
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
      _uploadedPathsByRequest
          .putIfAbsent(requestId, () => {})
          .add(uploadedPath);
      return uploadedPath;
    } on StorageException {
      throw const DriverProfileChangeException(
        'Chưa thể tải ảnh lên. Vui lòng thử lại.',
      );
    }
  }

  Object? _normalizeValue(DriverProfileChangeField field, Object? value) {
    if (value is! String) return value;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return switch (field) {
      DriverProfileChangeField.email => normalized.toLowerCase(),
      DriverProfileChangeField.licensePlate ||
      DriverProfileChangeField.idCardNumber ||
      DriverProfileChangeField.driverLicenseNumber => normalized.toUpperCase(),
      _ => normalized,
    };
  }

  String _fileName(DriverProfileChangeField field) => switch (field) {
    DriverProfileChangeField.avatar => 'avatar',
    DriverProfileChangeField.idCardFront => 'id_card_front',
    DriverProfileChangeField.idCardBack => 'id_card_back',
    DriverProfileChangeField.driverLicense => 'driver_license',
    DriverProfileChangeField.vehiclePhoto => 'vehicle_photo',
    _ => throw const DriverProfileChangeException(
      'Trường thông tin này không hỗ trợ tải tệp.',
    ),
  };

  Set<String> _ownedFilePaths(
    String requestId,
    DriverProfileChangeRequest? request,
  ) {
    final paths = <String>{...?_uploadedPathsByRequest[requestId]};
    if (request?.id != requestId) return paths;
    for (final field in const [
      DriverProfileChangeField.avatar,
      DriverProfileChangeField.idCardFront,
      DriverProfileChangeField.idCardBack,
      DriverProfileChangeField.driverLicense,
      DriverProfileChangeField.vehiclePhoto,
    ]) {
      final value = request?.requestedChanges?[field.requestKey];
      if (value is String && value.isNotEmpty) paths.add(value);
    }
    return paths;
  }

  Future<void> _removeBestEffort(Set<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _gateway.remove(paths.toList(growable: false));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[DriverProfileChange] draft cleanup failed: $error');
      }
    }
  }

  DriverProfileChangeRequest _requestFromResponse(Object? response) {
    if (response is Map) {
      return DriverProfileChangeRequest.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    if (response is List && response.length == 1 && response.first is Map) {
      return DriverProfileChangeRequest.fromJson(
        Map<String, dynamic>.from(response.first as Map),
      );
    }
    throw const DriverProfileChangeException(
      'Máy chủ trả về dữ liệu yêu cầu không hợp lệ.',
    );
  }
}

class SupabaseDriverProfileChangeGateway implements DriverProfileChangeGateway {
  SupabaseDriverProfileChangeGateway({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'driver_profile_change_requests';
  static const _bucket = 'driver-profile-request-files';
  static const _selection =
      'id, driver_id, requested_by, current_snapshot, requested_changes, '
      'reason, status, decided_by, decided_at, decision_reason, created_at, '
      'updated_at';

  @override
  Future<Object?> rpc(
    String function, {
    Map<String, Object?> params = const {},
  }) {
    return _client.rpc(function, params: params);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLatestRows() async {
    final rows = await _client
        .from(_table)
        .select(_selection)
        .order('created_at', ascending: false)
        .limit(1);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchLatestRows() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(1);
  }

  @override
  Future<String> upload({
    required String path,
    required List<int> bytes,
    required String contentType,
  }) async {
    return _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  @override
  Future<void> remove(List<String> paths) async {
    await _client.storage.from(_bucket).remove(paths);
  }
}

class DriverProfileChangeException implements Exception {
  const DriverProfileChangeException(this.message);

  final String message;

  factory DriverProfileChangeException.fromPostgrest(PostgrestException error) {
    final detail = '${error.message} ${error.details}'.toUpperCase();
    if (detail.contains('ACTIVE_PROFILE_CHANGE_REQUEST_EXISTS')) {
      return const DriverProfileChangeException(
        'Bạn đã có một yêu cầu đang chờ Admin xử lý.',
      );
    }
    if (detail.contains('NO_PROFILE_CHANGES')) {
      return const DriverProfileChangeException(
        'Thông tin mới không khác hồ sơ hiện tại.',
      );
    }
    if (detail.contains('NOT_CANCELLABLE')) {
      return const DriverProfileChangeException(
        'Yêu cầu này không còn có thể hủy.',
      );
    }
    return const DriverProfileChangeException(
      'Chưa thể xử lý yêu cầu chỉnh sửa. Vui lòng thử lại.',
    );
  }

  @override
  String toString() => message;
}
