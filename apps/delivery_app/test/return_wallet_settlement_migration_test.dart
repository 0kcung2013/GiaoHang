import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith(
            '_refund_driver_advance_after_completed_return.sql',
          ),
        )
        .toList();
    expect(matches, hasLength(1));
    sql = matches.single.readAsStringSync();
  });

  test('completed return refunds advance and keeps return earning', () {
    final confirmReturn = _between(
      sql,
      'CREATE OR REPLACE FUNCTION public.confirm_order_return',
      'REVOKE ALL ON FUNCTION public.confirm_order_return',
    );

    expect(confirmReturn, contains("'return_earning'"));
    expect(confirmReturn, contains("'cod_release'"));
    expect(confirmReturn, contains(':return_cod_release'));
    expect(confirmReturn, contains("'driver_advance_refunded', true"));
    expect(confirmReturn, isNot(contains(':customer_failed_credit')));
    expect(confirmReturn, isNot(contains("'failed_delivery_credit'")));
  });

  test('historical incorrect return settlement is compensated once', () {
    expect(sql, contains("'adjustment_debit'"));
    expect(sql, contains(':reverse_customer_failed_credit'));
    expect(sql, contains('ON CONFLICT (idempotency_key) DO NOTHING'));
    expect(sql, contains("capture.available_delta < 0"));
  });

  test('false delivered outcome stays outside the return refund command', () {
    expect(sql, isNot(contains('advance_driver_order_status')));
    expect(
      sql,
      contains(
        'A false delivered confirmation remains the Driver responsibility',
      ),
    );
  });
}

String _between(String source, String start, String end) {
  return source.split(start)[1].split(end)[0];
}
