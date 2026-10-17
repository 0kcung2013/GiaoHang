import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  File financeMigration() {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_driver_wallet_finance.sql'))
        .toList();
    expect(matches, hasLength(1));
    return matches.single;
  }

  File fixedCustomerFeeMigration() {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_customer_fixed_platform_fee.sql'))
        .toList();
    expect(matches, hasLength(1));
    return matches.single;
  }

  File removePlatformFeeMigration() {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_remove_platform_fee.sql'))
        .toList();
    expect(matches, hasLength(1));
    return matches.single;
  }

  test('finance migration creates only the two approved tables', () {
    final sql = financeMigration().readAsStringSync();
    final createdTables = RegExp(
      r'CREATE TABLE(?: IF NOT EXISTS)? public\.([a-z_]+)',
      caseSensitive: false,
    ).allMatches(sql).map((match) => match.group(1)).toSet();

    expect(createdTables, {'driver_wallet_transactions', 'system_settings'});
    expect(sql, contains('ALTER TABLE public.orders'));
    expect(sql, contains('available_delta bigint'));
    expect(sql, contains('held_delta bigint'));
    expect(sql, contains('platform_fee_rate_bps'));
  });

  test('finance tables are RLS protected and client writes are revoked', () {
    final sql = financeMigration().readAsStringSync();

    expect(
      sql,
      contains(
        'ALTER TABLE public.driver_wallet_transactions ENABLE ROW LEVEL SECURITY',
      ),
    );
    expect(
      sql,
      contains('ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY'),
    );
    expect(
      sql,
      contains(
        'REVOKE INSERT, UPDATE, DELETE ON public.driver_wallet_transactions',
      ),
    );
    expect(
      sql,
      contains('REVOKE INSERT, UPDATE, DELETE ON public.system_settings'),
    );
  });

  test('wallet commands are idempotent and restricted to explicit roles', () {
    final sql = financeMigration().readAsStringSync();

    expect(sql, contains('idempotency_key text NOT NULL UNIQUE'));
    expect(sql, contains('FUNCTION public.get_driver_wallet_summary'));
    expect(sql, contains('FUNCTION public.create_driver_wallet_topup'));
    expect(sql, contains('FUNCTION public.complete_driver_wallet_topup'));
    expect(sql, contains('FUNCTION public.update_platform_fee_rate'));
    expect(sql, contains("SET search_path = ''"));
    expect(sql, contains('FROM PUBLIC, anon'));
  });

  test('order lifecycle owns COD reserve capture release and settlement', () {
    final sql = financeMigration().readAsStringSync();

    expect(sql, contains('INSUFFICIENT_WALLET_BALANCE'));
    expect(sql, contains("'cod_hold'"));
    expect(sql, contains("'cod_release'"));
    expect(sql, contains("'cod_advance_capture'"));
    expect(sql, contains("'platform_fee_capture'"));
    expect(sql, contains("'prepaid_earning'"));
    expect(sql, contains("'cod_settlement'"));
  });

  test(
    'fixed fee migration charges customer without reducing driver income',
    () {
      final sql = fixedCustomerFeeMigration().readAsStringSync();

      expect(sql, isNot(contains('CREATE TABLE')));
      expect(sql, contains("'platform_fee_amount', to_jsonb(1000)"));
      expect(
        sql,
        contains('v_platform_fee := public.get_platform_fee_amount()'),
      );
      expect(sql, contains('v_delivery_fee + v_platform_fee'));
      expect(sql, contains('0, v_platform_fee, v_delivery_fee'));
      expect(
        sql,
        contains('v_required_balance := v_order.driver_advance_amount'),
      );
      expect(sql, contains('v_order.offered_driver_id IS DISTINCT FROM'));
    },
  );

  test('latest migration retires the platform fee for new orders', () {
    final sql = removePlatformFeeMigration().readAsStringSync();

    expect(sql, contains("'platform_fee_amount', to_jsonb(0)"));
    expect(sql, contains('SELECT 0::bigint'));
    expect(sql, contains('SECURITY INVOKER'));
    expect(sql, contains('ALTER COLUMN platform_fee_amount SET DEFAULT 0'));
    expect(sql, contains('platform_fee_amount = 0'));
    expect(sql, contains("status IN ("));
  });
}
