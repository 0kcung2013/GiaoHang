import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('_pickup_wallet_customer_settlement.sql'),
        )
        .toList();
    expect(matches, hasLength(1));
    sql = matches.single.readAsStringSync();
  });

  test('customer wallet ledger is immutable RLS protected and realtime', () {
    expect(sql, contains('CREATE TABLE public.customer_wallet_transactions'));
    expect(
      sql,
      contains(
        'ALTER TABLE public.customer_wallet_transactions ENABLE ROW LEVEL SECURITY',
      ),
    );
    expect(
      sql,
      contains(
        'REVOKE INSERT, UPDATE, DELETE ON public.customer_wallet_transactions',
      ),
    );
    expect(sql, contains('customer_wallet_transactions_select_related'));
    expect(sql, contains('ADD TABLE public.customer_wallet_transactions'));
    expect(sql, contains('idempotency_key text NOT NULL UNIQUE'));
  });

  test('accept checks wallet without holding or debiting it', () {
    final accept = _between(
      sql,
      'CREATE OR REPLACE FUNCTION public.accept_order',
      'CREATE OR REPLACE FUNCTION public.advance_driver_order_status',
    );

    expect(accept, contains('INSUFFICIENT_WALLET_BALANCE'));
    expect(accept, contains('v_order.driver_advance_amount'));
    expect(accept, isNot(contains("'cod_hold'")));
    expect(
      accept,
      isNot(contains('INSERT INTO public.driver_wallet_transactions')),
    );
  });

  test('pickup directly debits available balance with legacy hold support', () {
    final advance = _between(
      sql,
      'CREATE OR REPLACE FUNCTION public.advance_driver_order_status',
      'CREATE OR REPLACE FUNCTION public.confirm_order_return',
    );

    expect(advance, contains('INSUFFICIENT_WALLET_BALANCE_AT_PICKUP'));
    expect(advance, contains("jsonb_build_object('source', 'pickup_debit')"));
    expect(advance, contains("jsonb_build_object('source', 'legacy_hold')"));
    expect(
      advance,
      contains('v_order.driver_advance_amount, -v_order.driver_advance_amount'),
    );
  });

  test(
    'delivered and failed outcomes credit the order creator exactly once',
    () {
      expect(sql, contains("'delivery_credit'"));
      expect(sql, contains("'failed_delivery_credit'"));
      expect(sql, contains("'risk_credit'"));
      expect(sql, contains(':customer_delivery_credit'));
      expect(sql, contains(':customer_failed_credit'));
      expect(sql, contains(':customer_risk_credit'));

      final confirmReturn = _between(
        sql,
        'CREATE OR REPLACE FUNCTION public.confirm_order_return',
        'CREATE OR REPLACE FUNCTION public.confirm_risk_custody_resolved',
      );
      expect(confirmReturn, isNot(contains(':return_cod_release')));
      expect(confirmReturn, contains("'driver_advance_refunded', false"));
    },
  );

  test('driver availability has an authenticated RPC', () {
    final availability = _between(
      sql,
      'CREATE OR REPLACE FUNCTION public.set_driver_availability',
      'CREATE OR REPLACE FUNCTION public.accept_order',
    );

    expect(sql, contains('FUNCTION public.set_driver_availability'));
    expect(availability, contains('p_is_available = false'));
    expect(
      sql,
      matches(
        RegExp(
          r'REVOKE ALL ON FUNCTION public\.set_driver_availability\(boolean\)\s+'
          r'FROM PUBLIC, anon;',
        ),
      ),
    );
    expect(
      sql,
      matches(
        RegExp(
          r'GRANT EXECUTE ON FUNCTION public\.set_driver_availability\(boolean\)\s+'
          r'TO authenticated;',
        ),
      ),
    );
  });
}

String _between(String source, String start, String end) {
  return source.split(start)[1].split(end)[0];
}
