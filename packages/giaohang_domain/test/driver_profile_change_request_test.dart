import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:test/test.dart';

void main() {
  test('parses a pending request and builds only changed field diffs', () {
    final request = DriverProfileChangeRequest.fromJson({
      'id': 'request-1',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': {'phone': '0900000000', 'vehicle_color': 'Đen'},
      'requested_changes': {'phone': '0911111111', 'vehicle_color': 'Đen'},
      'reason': 'Đổi số liên hệ',
      'status': 'pending',
      'decision_reason': null,
      'created_at': '2026-08-24T03:00:00+07:00',
      'updated_at': '2026-08-24T03:05:00+07:00',
      'decided_at': null,
    });

    expect(request.id, 'request-1');
    expect(request.driverId, 'driver-1');
    expect(request.requestedBy, 'user-1');
    expect(request.reason, 'Đổi số liên hệ');
    expect(request.currentSnapshot?['phone'], '0900000000');
    expect(request.requestedChanges?['phone'], '0911111111');
    expect(request.status, DriverProfileChangeStatus.pending);
    expect(request.isActive, isTrue);
    expect(request.canDriverCancel, isTrue);
    expect(request.createdAt, DateTime.utc(2026, 8, 23, 20));
    expect(request.updatedAt, DateTime.utc(2026, 8, 23, 20, 5));
    expect(request.decidedAt, isNull);
    expect(request.decisionReason, isNull);
    expect(buildDriverProfileDiff(request), [
      const DriverProfileFieldDiff(
        field: DriverProfileChangeField.phone,
        currentValue: '0900000000',
        requestedValue: '0911111111',
      ),
    ]);
  });

  test('maps every database lifecycle value', () {
    expect(
      DriverProfileChangeStatus.values.map((value) => value.databaseValue),
      [
        'draft',
        'pending',
        'applying',
        'approved',
        'rejected',
        'cancelled',
        'conflicted',
      ],
    );
    expect(
      DriverProfileChangeStatus.fromDatabase('conflicted'),
      DriverProfileChangeStatus.conflicted,
    );
  });

  test('maps every editable field to its request payload key', () {
    expect(DriverProfileChangeField.values.map((field) => field.requestKey), [
      'full_name',
      'email',
      'phone',
      'avatar_path',
      'vehicle_type',
      'vehicle_brand_model',
      'vehicle_color',
      'license_plate',
      'id_card_number',
      'id_card_front_path',
      'id_card_back_path',
      'driver_license_number',
      'driver_license_path',
      'vehicle_photo_path',
    ]);
  });

  test('maps proposed file paths to their current profile URL fields', () {
    final request = DriverProfileChangeRequest.fromJson({
      'id': 'request-2',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': {
        'avatar_url': 'https://legacy.test/avatar.jpg',
        'id_card_front_url': 'https://legacy.test/id-front.jpg',
      },
      'requested_changes': {
        'avatar_path': 'user-1/request-2/avatar.jpg',
        'id_card_front_path': 'user-1/request-2/id-front.jpg',
      },
      'reason': 'Cập nhật ảnh',
      'status': 'pending',
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
    });

    expect(buildDriverProfileDiff(request), [
      const DriverProfileFieldDiff(
        field: DriverProfileChangeField.avatar,
        currentValue: 'https://legacy.test/avatar.jpg',
        requestedValue: 'user-1/request-2/avatar.jpg',
      ),
      const DriverProfileFieldDiff(
        field: DriverProfileChangeField.idCardFront,
        currentValue: 'https://legacy.test/id-front.jpg',
        requestedValue: 'user-1/request-2/id-front.jpg',
      ),
    ]);
  });

  test('keeps profile diffs in canonical field order', () {
    final request = DriverProfileChangeRequest.fromJson({
      'id': 'request-order',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': {
        'full_name': 'Tên cũ',
        'license_plate': '59-X1 000.00',
      },
      'requested_changes': {
        'license_plate': '59-X1 123.45',
        'full_name': 'Tên mới',
      },
      'reason': 'Cập nhật thông tin',
      'status': 'pending',
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
    });

    expect(buildDriverProfileDiff(request).map((diff) => diff.field), [
      DriverProfileChangeField.fullName,
      DriverProfileChangeField.licensePlate,
    ]);
  });

  test('serializes a nullable draft with UTC database timestamps', () {
    final request = DriverProfileChangeRequest.fromJson({
      'id': 'request-3',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': null,
      'requested_changes': null,
      'reason': null,
      'status': 'draft',
      'decided_by': null,
      'decided_at': null,
      'decision_reason': null,
      'created_at': '2026-08-24T10:00:00+07:00',
      'updated_at': '2026-08-24T10:05:00+07:00',
    });

    expect(request.toJson(), {
      'id': 'request-3',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': null,
      'requested_changes': null,
      'reason': null,
      'status': 'draft',
      'decided_by': null,
      'decided_at': null,
      'decision_reason': null,
      'created_at': '2026-08-24T03:00:00.000Z',
      'updated_at': '2026-08-24T03:05:00.000Z',
    });
  });

  test('limits active and driver-cancellable lifecycle states', () {
    expect(_requestWithStatus('draft').isActive, isTrue);
    expect(_requestWithStatus('pending').isActive, isTrue);
    expect(_requestWithStatus('applying').isActive, isTrue);
    expect(_requestWithStatus('approved').isActive, isFalse);
    expect(_requestWithStatus('rejected').isActive, isFalse);
    expect(_requestWithStatus('cancelled').isActive, isFalse);
    expect(_requestWithStatus('conflicted').isActive, isFalse);

    expect(_requestWithStatus('draft').canDriverCancel, isTrue);
    expect(_requestWithStatus('pending').canDriverCancel, isTrue);
    expect(_requestWithStatus('applying').canDriverCancel, isFalse);
    expect(_requestWithStatus('approved').canDriverCancel, isFalse);
  });
}

DriverProfileChangeRequest _requestWithStatus(String status) =>
    DriverProfileChangeRequest.fromJson({
      'id': 'request-status',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'status': status,
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
    });
