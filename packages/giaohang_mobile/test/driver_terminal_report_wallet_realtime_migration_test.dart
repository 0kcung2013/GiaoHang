import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    final migrations = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith(
            '_harden_terminal_driver_reports_and_wallet_realtime.sql',
          ),
        )
        .toList();
    expect(migrations, hasLength(1));
    sql = migrations.single.readAsStringSync();
  });

  test('publishes wallet transactions for realtime refresh', () {
    expect(sql, contains('ALTER PUBLICATION supabase_realtime'));
    expect(sql, contains('ADD TABLE public.driver_wallet_transactions'));
    expect(sql, contains('pg_publication_tables'));
  });

  test('rejects only driver reports after successful delivery', () {
    expect(sql, contains("NEW.reporter_role_snapshot = 'driver'"));
    expect(sql, contains("order_status = 'delivered'"));
    expect(sql, contains('DRIVER_REPORT_AFTER_DELIVERY'));
    expect(sql, isNot(contains("NEW.reporter_role_snapshot = 'customer'")));
  });

  test('counts return earnings in the Vietnam business day', () {
    expect(sql, contains("'return_earning'"));
    expect(sql, contains("AT TIME ZONE 'Asia/Ho_Chi_Minh'"));
    expect(sql, contains('FUNCTION public.get_driver_wallet_summary'));
  });
}
