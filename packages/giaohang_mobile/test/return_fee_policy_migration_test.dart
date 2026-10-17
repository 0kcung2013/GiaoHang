import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;
  late String compatibilitySql;

  setUpAll(() {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_return_fee_fifty_percent.sql'))
        .toList();
    expect(matches, hasLength(1));
    sql = matches.single.readAsStringSync();

    final compatibilityMatches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith(
            '_make_return_fee_client_backward_compatible.sql',
          ),
        )
        .toList();
    expect(compatibilityMatches, hasLength(1));
    compatibilitySql = compatibilityMatches.single.readAsStringSync();
  });

  test('backend fixes fee at 50 percent and ignores legacy client quote', () {
    final approval = _between(
      compatibilitySql,
      'CREATE OR REPLACE FUNCTION public.support_approve_return',
      'REVOKE ALL ON FUNCTION public.support_approve_return',
    );

    expect(approval, contains('return_order.delivery_fee'));
    expect(approval, contains('* 0.5'));
    expect(approval, contains('expected_return_fee'));
    expect(approval, isNot(contains('RETURN_FEE_MISMATCH')));
    expect(
      approval,
      isNot(contains('p_customer_return_charge, p_driver_return_earning')),
    );
    expect(approval, contains("p_fee_payer <> 'platform'"));
    expect(approval, contains('RETURN_CUSTOMER_CHARGE_NOT_SUPPORTED'));
  });

  test('completion credits delivery earning and return fee once', () {
    final completion = _between(
      sql,
      'CREATE OR REPLACE FUNCTION public.confirm_order_return',
      'REVOKE ALL ON FUNCTION public.confirm_order_return',
    );

    expect(completion, contains("'return_delivery_earning'"));
    expect(completion, contains("'return_earning'"));
    expect(completion, contains(':return_delivery_earning'));
    expect(completion, contains(':return_earning'));
    expect(completion, contains('ON CONFLICT (idempotency_key) DO NOTHING'));
    expect(completion, contains("'return_fee_rate_bps', 5000"));
    expect(completion, isNot(contains('thưởng')));
    expect(completion, isNot(contains('Thưởng')));
  });

  test('active returns adopt policy without retroactive completed payout', () {
    expect(sql, contains("active_return.status IN ('approved', 'returning')"));
    expect(sql, isNot(contains("active_return.status = 'returned'")));
    expect(sql, isNot(contains('historical_return_payout')));
  });

  test('wallet summary counts both returned-order income entries', () {
    final summary = _between(
      sql,
      'CREATE OR REPLACE FUNCTION public.get_driver_wallet_summary',
      'REVOKE ALL ON FUNCTION public.get_driver_wallet_summary',
    );

    expect(summary, contains("'return_delivery_earning'"));
    expect(summary, contains("'return_earning'"));
  });
}

String _between(String source, String start, String end) {
  return source.split(start)[1].split(end)[0];
}
