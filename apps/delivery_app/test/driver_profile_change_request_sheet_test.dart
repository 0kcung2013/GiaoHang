import 'package:delivery_app/features/driver/screens/account/data/driver_profile_change_repository.dart';
import 'package:delivery_app/features/driver/screens/account/dialogs/driver_profile_change_request_sheet.dart';
import 'package:delivery_app/features/driver/screens/account/models/driver_account_view_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  testWidgets('reviews old and new values before submitting', (tester) async {
    final repository = FakeDriverProfileChangeRepository();
    await tester.pumpWidget(
      _testApp(
        DriverProfileChangeRequestSheet(
          profile: _profile,
          repository: repository,
        ),
      ),
    );

    await tester.tap(find.text('Số điện thoại'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('phone-change-input')),
      '0911111111',
    );
    await tester.enterText(
      find.byKey(const Key('profile-change-reason')),
      'Đổi số liên hệ',
    );
    await tester.tap(find.text('Xem lại'));
    await tester.pumpAndSettle();

    expect(find.text('0900000000'), findsOneWidget);
    expect(find.text('0911111111'), findsOneWidget);
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();

    expect(repository.submitCount, 1);
    expect(repository.lastReason, 'Đổi số liên hệ');
  });
}

const _profile = DriverAccountViewData(
  driverId: 'driver-1',
  name: 'Nguyễn Minh Tài',
  email: 'tai.xe@example.com',
  phone: '0900000000',
  avatarUrl: null,
  isAvailable: true,
  approvalStatus: 'approved',
  totalDeliveries: 128,
  vehicleType: 'motorbike',
  vehicleBrandModel: 'Honda Air Blade',
  vehicleColor: 'Đen nhám',
  licensePlate: '59-X1 123.45',
  hasIdentityCard: true,
  hasDriverLicense: true,
  hasVehiclePhoto: true,
);

Widget _testApp(Widget child) => MaterialApp(home: Scaffold(body: child));

class FakeDriverProfileChangeRepository
    implements DriverProfileChangeRepository {
  int submitCount = 0;
  String? lastReason;

  @override
  Future<DriverProfileChangeRequest> createDraft() async =>
      _request(status: 'draft', reason: null, changes: const {});

  @override
  Future<DriverProfileChangeRequest> submit({
    required String requestId,
    required Map<DriverProfileChangeField, Object?> changes,
    required String reason,
  }) async {
    submitCount++;
    lastReason = reason;
    return _request(
      status: 'pending',
      reason: reason,
      changes: {
        for (final entry in changes.entries) entry.key.requestKey: entry.value,
      },
    );
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<DriverProfileChangeRequest?> fetchLatest() async => null;

  @override
  Stream<DriverProfileChangeRequest?> watchLatest() => const Stream.empty();

  @override
  Future<String> uploadDraftFile({
    required String requestId,
    required DriverProfileChangeField field,
    required List<int> bytes,
    required String extension,
    required String contentType,
  }) async => 'user-1/$requestId/${field.requestKey}.$extension';
}

DriverProfileChangeRequest _request({
  required String status,
  required String? reason,
  required Map<String, Object?> changes,
}) {
  return DriverProfileChangeRequest.fromJson({
    'id': 'request-1',
    'driver_id': 'driver-1',
    'requested_by': 'user-1',
    'current_snapshot': {'phone': '0900000000'},
    'requested_changes': changes,
    'reason': reason,
    'status': status,
    'created_at': '2026-08-24T03:00:00Z',
    'updated_at': '2026-08-24T03:00:00Z',
  });
}
