import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String repository;

  setUpAll(() {
    migration = File(
      '../../supabase/migrations/20260917053843_safely_consolidate_legacy_tables.sql',
    ).readAsStringSync();
    repository = File(
      'lib/features/risk_reports/data/risk_report_repository.dart',
    ).readAsStringSync();
  });

  test('preserves every legacy location before dropping with RESTRICT', () {
    expect(migration, contains('insert into public.driver_locations'));
    expect(migration, contains('rows were not preserved'));
    expect(migration, contains('drop table public.locations restrict'));
    expect(
      migration.toLowerCase(),
      isNot(contains('drop table public.locations cascade')),
    );
  });

  test('mirrors internal notes while old clients still use the legacy table', () {
    expect(migration, contains('insert into public.risk_report_messages'));
    expect(migration, contains('insert into public.risk_report_notes'));
    expect(migration, contains("'internal'"));
    expect(
      migration,
      isNot(contains('drop table if exists public.risk_report_notes')),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.add_risk_report_note(uuid, text) to authenticated',
      ),
    );
  });

  test('operations repository reads notes from internal messages', () {
    expect(repository, contains(".from('risk_report_messages')"));
    expect(repository, contains('author_id:sender_id'));
    expect(repository, contains(".eq('visibility', 'internal')"));
  });
}
