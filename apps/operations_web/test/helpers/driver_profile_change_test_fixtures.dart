import 'package:flutter/material.dart';
import 'dart:async';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:operations_web/features/admin/screens/drivers/profile_changes/data/admin_driver_media_resolver.dart';
import 'package:operations_web/features/admin/screens/drivers/profile_changes/data/admin_driver_profile_change_repository.dart';

Widget testApp(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 1100, child: child)),
);

DriverProfileChangeRequest pendingRequestFixture() =>
    DriverProfileChangeRequest.fromJson({
      'id': 'request-1',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': {
        'full_name': 'Nguyễn Minh Tài',
        'phone': '0900000000',
      },
      'requested_changes': {'phone': '0911111111'},
      'reason': 'Đổi số liên hệ',
      'status': 'pending',
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
    });

DriverModel approvedDriverFixture() => DriverModel(
  id: 'driver-1',
  userId: 'user-1',
  vehicleType: 'motorbike',
  licensePlate: '59-X1 123.45',
  vehicleBrandModel: 'Honda Air Blade',
  vehicleColor: 'Đen nhám',
  isAvailable: true,
  updatedAt: DateTime.utc(2026, 8, 24),
  totalDeliveries: 128,
  approvalStatus: 'approved',
  fullName: 'Nguyễn Minh Tài',
);

class FakeAdminDriverProfileChangeRepository
    implements AdminDriverProfileChangeRepository {
  FakeAdminDriverProfileChangeRepository({required this.requests});

  final List<DriverProfileChangeRequest> requests;
  int approveCount = 0;
  int rejectCount = 0;
  int fetchCount = 0;
  String? lastRejectionReason;
  final _changes = StreamController<void>.broadcast();

  @override
  Future<List<DriverProfileChangeRequest>> fetchPending() async {
    fetchCount++;
    return requests;
  }

  @override
  Stream<void> watchChanges() async* {
    yield null;
    yield* _changes.stream;
  }

  void emitChange() => _changes.add(null);

  Future<void> dispose() => _changes.close();

  @override
  Future<void> approve(DriverProfileChangeRequest request) async {
    approveCount++;
  }

  @override
  Future<void> reject(String requestId, String reason) async {
    rejectCount++;
    lastRejectionReason = reason;
  }
}

class FakeAdminDriverMediaResolver implements AdminDriverMediaResolver {
  @override
  Future<String?> resolve(String? storedValue) async => storedValue;
}
