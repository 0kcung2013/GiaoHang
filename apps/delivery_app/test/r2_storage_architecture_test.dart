import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String relativePath) => File(relativePath).readAsStringSync();

  test('GPS history flush archives chunks to R2 instead of Postgres', () {
    final source = read('../../supabase/functions/flush-gps-history/index.ts');

    expect(source, contains('/v1/gps/chunks'));
    expect(source, contains('R2_GPS_INGEST_SECRET'));
    expect(source, contains('order_id: p.order_id'));
    expect(source, isNot(contains('.from("driver_locations").insert')));
  });

  test('R2 compatibility migrations reuse existing business tables', () {
    final profile = read(
      '../../supabase/migrations/'
      '20260918121450_accept_r2_driver_profile_media.sql',
    ).toLowerCase();
    final risk = read(
      '../../supabase/migrations/'
      '20260918121457_accept_r2_risk_evidence.sql',
    ).toLowerCase();

    expect(profile, contains('r2://media/users/'));
    expect(risk, contains('r2://media/orders/'));
    expect('$profile\n$risk', isNot(contains('create table')));
  });

  test('all new media uploads are R2-only', () {
    final uploadSources = [
      read('lib/core/services/cargo_image_service.dart'),
      read('lib/core/services/delivery_proof_service.dart'),
      read('lib/core/services/driver_kyc_storage_service.dart'),
      read(
        'lib/features/driver/screens/account/data/'
        'driver_profile_change_repository.dart',
      ),
      read('lib/features/risk_reports/data/risk_report_repository.dart'),
    ].join('\n');

    expect(uploadSources, isNot(contains('.uploadBinary(')));
    expect(uploadSources, isNot(contains('if (_r2.isConfigured)')));
  });
}
