import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;
  late String searchSql;
  late String claimSql;
  late String acceptOrderSql;

  setUpAll(() {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) {
          final contents = file.readAsStringSync().toLowerCase();
          return contents.contains(
                'function public.get_free_pick_orders_in_view',
              ) &&
              contents.contains('function public.claim_free_pick_order');
        })
        .toList();
    expect(matches, isNotEmpty);
    matches.sort((left, right) => left.path.compareTo(right.path));
    sql = matches.last.readAsStringSync().toLowerCase();

    final searchStart = sql.indexOf(
      'function public.get_free_pick_orders_in_view',
    );
    final claimStart = sql.indexOf(
      'function public.claim_free_pick_order',
      searchStart + 1,
    );
    searchSql = sql.substring(searchStart, claimStart);
    claimSql = sql.substring(claimStart);

    final acceptOrderMigrations =
        Directory('../../supabase/migrations')
            .listSync()
            .whereType<File>()
            .where(
              (file) => file.readAsStringSync().toLowerCase().contains(
                'function public.accept_order',
              ),
            )
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));
    expect(acceptOrderMigrations, isNotEmpty);
    acceptOrderSql = acceptOrderMigrations.last
        .readAsStringSync()
        .toLowerCase();
  });

  test('search returns an expired offer to a previously skipped driver', () {
    expect(searchSql, contains('offer_expires_at <= now()'));
    expect(searchSql, isNot(contains('? driver_user_id::text')));
  });

  test('claim allows manual retry but never steals another live offer', () {
    expect(claimSql, isNot(contains('? driver_user_id::text')));
    expect(claimSql, contains('free_pick_order_reserved'));
    expect(claimSql, contains('public.accept_order(p_order_id)'));
  });

  test('preserves server eligibility guards in viewport search', () {
    for (final guard in [
      'auth_required',
      'driver_profile_not_found',
      'driver_not_approved',
      'driver_offline',
      'driver_location_stale',
      'driver_has_active_order',
      'driver_has_active_offer',
      "payment_status in ('not_required', 'paid')",
      'assignment_timed_out_at is null',
      'assignment_expires_at > now()',
      'public.st_dwithin',
      '50000',
    ]) {
      expect(
        searchSql,
        contains(guard),
        reason: 'Missing search guard: $guard',
      );
    }
  });

  test('preserves atomic claim and final accept_order protections', () {
    for (final guard in [
      'auth_required',
      'driver_profile_not_found',
      'driver_location_stale',
      'for update',
      'assignment_expires_at <= clock_timestamp()',
      'free_pick_order_reserved',
      'public.st_dwithin',
      '50000',
      'driver_has_active_offer',
      'public.accept_order(p_order_id)',
    ]) {
      expect(claimSql, contains(guard), reason: 'Missing claim guard: $guard');
    }

    for (final delegatedGuard in [
      'driver_not_approved',
      'driver_offline',
      'driver_has_active_order',
      'order_payment_incomplete',
      'assignment_expired',
      'insufficient_wallet_balance',
    ]) {
      expect(
        acceptOrderSql,
        contains(delegatedGuard),
        reason: 'Missing accept_order guard: $delegatedGuard',
      );
    }
  });

  test('keeps the FreePick RPC surface restricted to signed-in drivers', () {
    expect(
      RegExp(
        r'revoke all on function public\.get_free_pick_orders_in_view[\s\S]*from public, anon;',
      ).hasMatch(sql),
      isTrue,
    );
    expect(
      RegExp(
        r'grant execute on function public\.get_free_pick_orders_in_view[\s\S]*to authenticated;',
      ).hasMatch(sql),
      isTrue,
    );
    expect(
      RegExp(
        r'revoke all on function public\.claim_free_pick_order\(uuid\)[\s\S]*from public, anon;',
      ).hasMatch(sql),
      isTrue,
    );
  });
}
