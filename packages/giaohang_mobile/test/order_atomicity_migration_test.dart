import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/'
    '20260730134707_atomic_customer_order_commands.sql',
  );

  test('migration owns all create-order writes in one database function', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('FUNCTION public.create_customer_order'));
    expect(sql, contains('INSERT INTO public.orders'));
    expect(sql, contains('INSERT INTO public.order_items'));
    expect(sql, contains('INSERT INTO public.order_status_logs'));
    expect(sql, contains('v_customer_user_id uuid := auth.uid()'));
    expect(sql, contains("'customer'::public.user_role"));
    expect(
      sql,
      contains('GRANT EXECUTE ON FUNCTION public.create_customer_order'),
    );
  });

  test('migration locks and cancels the owned order with its status log', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('FUNCTION public.cancel_customer_order'));
    expect(sql, contains('FOR UPDATE'));
    expect(sql, contains('UPDATE public.orders'));
    expect(sql, contains("'cancelled'::public.order_status"));
    expect(
      sql,
      contains('GRANT EXECUTE ON FUNCTION public.cancel_customer_order'),
    );
  });

  test('atomic command functions have explicit execution privileges', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('SET search_path ='));
    expect(
      RegExp(
        r'REVOKE ALL ON FUNCTION[\s\S]+?FROM PUBLIC, anon;',
      ).allMatches(sql),
      hasLength(2),
    );
  });
}
