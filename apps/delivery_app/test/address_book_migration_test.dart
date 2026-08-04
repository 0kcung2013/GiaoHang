import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/'
    '20260803034350_customer_address_book.sql',
  );

  test('migration creates address tables with ownership RLS and grants', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('CREATE TABLE IF NOT EXISTS public.saved_addresses'));
    expect(sql, contains('CREATE TABLE IF NOT EXISTS public.recent_addresses'));
    expect(RegExp(r'ENABLE ROW LEVEL SECURITY').allMatches(sql), hasLength(2));
    expect(sql, contains('user_id = (SELECT auth.uid())'));
    expect(
      sql,
      contains(
        'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.saved_addresses TO authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.recent_addresses TO authenticated',
      ),
    );
  });

  test('migration enforces one default and records bounded recent history', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('saved_addresses_one_default_per_user_idx'));
    expect(sql, contains('WHERE is_default'));
    expect(sql, contains('FUNCTION public.record_recent_addresses'));
    expect(
      sql,
      contains('usage_count = public.recent_addresses.usage_count + 1'),
    );
    expect(sql, contains('OFFSET 15'));
    expect(sql, contains('SECURITY INVOKER'));
    expect(sql, contains('REVOKE ALL ON FUNCTION'));
  });

  test('new address schema does not introduce recipient contact columns', () {
    final sql = migration.readAsStringSync();

    expect(sql, isNot(contains('contact_name text')));
    expect(sql, isNot(contains('contact_phone text')));
  });
}
