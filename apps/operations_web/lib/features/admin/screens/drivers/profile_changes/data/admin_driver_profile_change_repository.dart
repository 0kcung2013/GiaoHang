import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AdminDriverProfileChangeRepository {
  Future<List<DriverProfileChangeRequest>> fetchPending();

  Stream<void> watchChanges();

  Future<void> approve(DriverProfileChangeRequest request);

  Future<void> reject(String requestId, String reason);
}

abstract interface class AdminDriverProfileChangeGateway {
  Future<List<Map<String, dynamic>>> fetchPendingRows();

  Stream<void> watchChanges();

  Future<Object?> rpc(
    String function, {
    Map<String, Object?> params = const {},
  });

  Future<void> invokeApproval(String requestId);
}

bool requiresProfileApprovalEdgeFunction(DriverProfileChangeRequest request) {
  final changes = request.requestedChanges ?? const <String, Object?>{};
  return changes.containsKey(DriverProfileChangeField.email.requestKey) ||
      changes.containsKey(DriverProfileChangeField.avatar.requestKey);
}

class SupabaseAdminDriverProfileChangeRepository
    implements AdminDriverProfileChangeRepository {
  SupabaseAdminDriverProfileChangeRepository({
    AdminDriverProfileChangeGateway? gateway,
  }) : _gateway = gateway ?? SupabaseAdminDriverProfileChangeGateway();

  final AdminDriverProfileChangeGateway _gateway;

  @override
  Future<List<DriverProfileChangeRequest>> fetchPending() async {
    try {
      final rows = await _gateway.fetchPendingRows();
      return rows
          .map(DriverProfileChangeRequest.fromJson)
          .where(
            (request) =>
                request.status == DriverProfileChangeStatus.pending ||
                request.status == DriverProfileChangeStatus.applying,
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw AdminDriverProfileChangeException.fromPostgrest(error);
    }
  }

  @override
  Stream<void> watchChanges() => _gateway.watchChanges();

  @override
  Future<void> approve(DriverProfileChangeRequest request) async {
    if (request.id.isEmpty) {
      throw const AdminDriverProfileChangeException(
        'Yêu cầu chỉnh sửa không hợp lệ.',
      );
    }
    try {
      if (requiresProfileApprovalEdgeFunction(request)) {
        await _gateway.invokeApproval(request.id);
        return;
      }
      await _gateway.rpc(
        'approve_driver_profile_change_request',
        params: {'p_request_id': request.id},
      );
    } on PostgrestException catch (error) {
      throw AdminDriverProfileChangeException.fromPostgrest(error);
    } on FunctionException catch (error) {
      throw AdminDriverProfileChangeException.fromFunction(error);
    }
  }

  @override
  Future<void> reject(String requestId, String reason) async {
    final normalizedReason = reason.trim();
    if (requestId.isEmpty) {
      throw const AdminDriverProfileChangeException(
        'Yêu cầu chỉnh sửa không hợp lệ.',
      );
    }
    if (normalizedReason.length < 3) {
      throw const AdminDriverProfileChangeException(
        'Vui lòng nhập lý do từ chối ít nhất 3 ký tự.',
      );
    }
    try {
      await _gateway.rpc(
        'reject_driver_profile_change_request',
        params: {'p_request_id': requestId, 'p_reason': normalizedReason},
      );
    } on PostgrestException catch (error) {
      throw AdminDriverProfileChangeException.fromPostgrest(error);
    }
  }
}

class SupabaseAdminDriverProfileChangeGateway
    implements AdminDriverProfileChangeGateway {
  SupabaseAdminDriverProfileChangeGateway({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'driver_profile_change_requests';
  static const _selection =
      'id, driver_id, requested_by, current_snapshot, requested_changes, '
      'reason, status, decided_by, decided_at, decision_reason, created_at, '
      'updated_at';

  @override
  Future<List<Map<String, dynamic>>> fetchPendingRows() async {
    final rows = await _client
        .from(_table)
        .select(_selection)
        .inFilter('status', const ['pending', 'applying'])
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Stream<void> watchChanges() {
    return _client.from(_table).stream(primaryKey: ['id']).map<void>((_) {});
  }

  @override
  Future<Object?> rpc(
    String function, {
    Map<String, Object?> params = const {},
  }) {
    return _client.rpc(function, params: params);
  }

  @override
  Future<void> invokeApproval(String requestId) async {
    final response = await _client.functions.invoke(
      'approve-driver-profile-change-request',
      body: {'request_id': requestId},
    );
    if (response.status < 200 || response.status >= 300) {
      throw FunctionException(
        status: response.status,
        details: response.data,
        reasonPhrase: 'Không thể áp dụng thay đổi hồ sơ.',
      );
    }
  }
}

class AdminDriverProfileChangeException implements Exception {
  const AdminDriverProfileChangeException(this.message);

  final String message;

  factory AdminDriverProfileChangeException.fromPostgrest(
    PostgrestException error,
  ) {
    final detail = '${error.message} ${error.details}'.toUpperCase();
    if (detail.contains('PROFILE_SNAPSHOT_CONFLICT')) {
      return const AdminDriverProfileChangeException(
        'Hồ sơ đã thay đổi. Yêu cầu được chuyển sang trạng thái xung đột.',
      );
    }
    if (detail.contains('NOT_PENDING')) {
      return const AdminDriverProfileChangeException(
        'Yêu cầu này đã được xử lý trước đó.',
      );
    }
    return const AdminDriverProfileChangeException(
      'Chưa thể xử lý yêu cầu. Vui lòng thử lại.',
    );
  }

  factory AdminDriverProfileChangeException.fromFunction(
    FunctionException error,
  ) {
    return const AdminDriverProfileChangeException(
      'Chưa thể cập nhật email hoặc ảnh đại diện. Vui lòng thử lại.',
    );
  }

  @override
  String toString() => message;
}
