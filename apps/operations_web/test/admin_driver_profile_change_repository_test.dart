import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:operations_web/features/admin/screens/drivers/profile_changes/data/admin_driver_profile_change_repository.dart';

void main() {
  test('routes email and avatar requests through the Edge Function', () {
    expect(
      requiresProfileApprovalEdgeFunction(
        requestFixture({'email': 'new@example.com'}),
      ),
      isTrue,
    );
    expect(
      requiresProfileApprovalEdgeFunction(
        requestFixture({'avatar_path': 'user/request/avatar.jpg'}),
      ),
      isTrue,
    );
    expect(
      requiresProfileApprovalEdgeFunction(
        requestFixture({'vehicle_color': 'Trắng'}),
      ),
      isFalse,
    );
  });

  test('approve and reject use whole-request commands', () async {
    final gateway = FakeAdminDriverProfileChangeGateway();
    final repository = SupabaseAdminDriverProfileChangeRepository(
      gateway: gateway,
    );

    await repository.approve(requestFixture({'vehicle_color': 'Trắng'}));
    expect(gateway.lastRpc, 'approve_driver_profile_change_request');
    expect(gateway.lastParams, {'p_request_id': 'request-1'});

    await repository.approve(requestFixture({'email': 'new@example.com'}));
    expect(gateway.lastInvokedRequestId, 'request-1');

    await repository.reject('request-1', ' Thông tin không khớp ');
    expect(gateway.lastRpc, 'reject_driver_profile_change_request');
    expect(gateway.lastParams, {
      'p_request_id': 'request-1',
      'p_reason': 'Thông tin không khớp',
    });
  });
}

DriverProfileChangeRequest requestFixture(Map<String, Object?> changes) {
  return DriverProfileChangeRequest.fromJson({
    'id': 'request-1',
    'driver_id': 'driver-1',
    'requested_by': 'user-1',
    'current_snapshot': {for (final key in changes.keys) key: 'current-value'},
    'requested_changes': changes,
    'reason': 'Cập nhật hồ sơ',
    'status': 'pending',
    'created_at': '2026-08-24T03:00:00Z',
    'updated_at': '2026-08-24T03:00:00Z',
  });
}

class FakeAdminDriverProfileChangeGateway
    implements AdminDriverProfileChangeGateway {
  String? lastRpc;
  Map<String, Object?>? lastParams;
  String? lastInvokedRequestId;

  @override
  Future<List<Map<String, dynamic>>> fetchPendingRows() async => const [];

  @override
  Future<void> invokeApproval(String requestId) async {
    lastInvokedRequestId = requestId;
  }

  @override
  Future<Object?> rpc(
    String function, {
    Map<String, Object?> params = const {},
  }) async {
    lastRpc = function;
    lastParams = params;
    return null;
  }

  @override
  Stream<void> watchChanges() => const Stream.empty();
}
