import 'dart:async';

import 'package:delivery_app/features/driver/screens/account/data/driver_profile_change_repository.dart';
import 'package:delivery_app/features/driver/screens/account/providers/driver_profile_change_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  testWidgets('approved request invalidates the driver account profile', (
    tester,
  ) async {
    final repository = FakeDriverProfileChangeRepository();
    var profileFetchCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverProfileChangeRepositoryProvider.overrideWithValue(repository),
          currentDriverAccountProfileProvider.overrideWith((ref) async {
            profileFetchCount++;
            return null;
          }),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(currentDriverAccountProfileProvider);
              ref.watch(currentDriverProfileChangeProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(profileFetchCount, 1);

    repository.emit(_request('approved'));
    await tester.pump();
    await tester.pump();

    expect(profileFetchCount, 2);
    await repository.dispose();
  });
}

class FakeDriverProfileChangeRepository
    implements DriverProfileChangeRepository {
  final _changes = StreamController<DriverProfileChangeRequest?>.broadcast();

  void emit(DriverProfileChangeRequest request) => _changes.add(request);

  Future<void> dispose() => _changes.close();

  @override
  Stream<DriverProfileChangeRequest?> watchLatest() => _changes.stream;

  @override
  Future<DriverProfileChangeRequest?> fetchLatest() async => null;

  @override
  Future<DriverProfileChangeRequest> createDraft() =>
      throw UnimplementedError();

  @override
  Future<DriverProfileChangeRequest> submit({
    required String requestId,
    required Map<DriverProfileChangeField, Object?> changes,
    required String reason,
  }) => throw UnimplementedError();

  @override
  Future<void> cancel(String requestId) => throw UnimplementedError();

  @override
  Future<String> uploadDraftFile({
    required String requestId,
    required DriverProfileChangeField field,
    required List<int> bytes,
    required String extension,
    required String contentType,
  }) => throw UnimplementedError();
}

DriverProfileChangeRequest _request(String status) =>
    DriverProfileChangeRequest.fromJson({
      'id': 'request-1',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': {'phone': '0900000000'},
      'requested_changes': {'phone': '0911111111'},
      'reason': 'Đổi số liên hệ',
      'status': status,
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
    });
