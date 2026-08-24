import 'package:delivery_app/features/driver/screens/account/data/driver_profile_change_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  test(
    'submit normalizes values and returns persisted pending request',
    () async {
      final gateway = FakeDriverProfileChangeGateway();
      final repository = SupabaseDriverProfileChangeRepository(
        gateway: gateway,
      );

      final request = await repository.submit(
        requestId: 'request-1',
        changes: const {
          DriverProfileChangeField.phone: ' 0911111111 ',
          DriverProfileChangeField.email: ' NEW@EXAMPLE.COM ',
          DriverProfileChangeField.licensePlate: ' 59-x1 123.45 ',
        },
        reason: ' Đổi số liên hệ ',
      );

      expect(gateway.lastFunction, 'submit_driver_profile_change_request');
      expect(gateway.lastChanges, {
        'phone': '0911111111',
        'email': 'new@example.com',
        'license_plate': '59-X1 123.45',
      });
      expect(gateway.lastReason, 'Đổi số liên hệ');
      expect(request.status, DriverProfileChangeStatus.pending);
    },
  );

  test('upload uses a stable owned request path', () async {
    final gateway = FakeDriverProfileChangeGateway();
    final repository = SupabaseDriverProfileChangeRepository(
      gateway: gateway,
      currentUserId: () => 'user-1',
    );

    final path = await repository.uploadDraftFile(
      requestId: 'request-1',
      field: DriverProfileChangeField.avatar,
      bytes: const [1, 2, 3],
      extension: 'JPEG',
      contentType: 'image/jpeg',
    );

    expect(path, 'user-1/request-1/avatar.jpeg');
    expect(gateway.lastUploadPath, path);
  });
}

class FakeDriverProfileChangeGateway implements DriverProfileChangeGateway {
  String? lastFunction;
  Map<String, Object?>? lastChanges;
  String? lastReason;
  String? lastUploadPath;

  @override
  Future<Object?> rpc(
    String function, {
    Map<String, Object?> params = const {},
  }) async {
    lastFunction = function;
    lastChanges = params['p_requested_changes'] == null
        ? null
        : Map<String, Object?>.from(params['p_requested_changes']! as Map);
    lastReason = params['p_reason'] as String?;
    return {
      'id': params['p_request_id'] ?? 'request-1',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': {'phone': '0900000000'},
      'requested_changes': lastChanges,
      'reason': lastReason,
      'status': function == 'create_driver_profile_change_draft'
          ? 'draft'
          : 'pending',
      'decided_by': null,
      'decision_reason': null,
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
      'decided_at': null,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLatestRows() async => const [];

  @override
  Stream<List<Map<String, dynamic>>> watchLatestRows() => const Stream.empty();

  @override
  Future<String> upload({
    required String path,
    required List<int> bytes,
    required String contentType,
  }) async {
    lastUploadPath = path;
    return path;
  }

  @override
  Future<void> remove(List<String> paths) async {}
}
