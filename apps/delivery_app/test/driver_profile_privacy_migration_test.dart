import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String migrationSql() {
    final files = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith('_driver_profile_privacy_hardening.sql'),
        )
        .toList();
    expect(files, hasLength(1));
    return files.single.readAsStringSync().toLowerCase();
  }

  test('hides driver rating and KYC from direct table reads', () {
    final sql = migrationSql();

    expect(
      sql,
      contains(
        'revoke select on table public.drivers from anon, authenticated',
      ),
    );
    final driverGrant = RegExp(
      r'grant select\s*\(([\s\S]*?)\)\s*on (?:table )?public\.drivers',
    ).firstMatch(sql)?.group(1);
    expect(driverGrant, isNotNull);
    expect(driverGrant, isNot(contains('rating')));
    expect(driverGrant, isNot(contains('id_card_number')));
    expect(driverGrant, isNot(contains('rejection_reason')));
    expect(sql, contains('drop policy if exists drivers_select_all'));
  });

  test('keeps direct driver writes limited to GPS telemetry', () {
    final sql = migrationSql();

    expect(
      sql,
      contains('revoke update on table public.drivers from authenticated'),
    );
    final driverUpdateGrant = RegExp(
      r'grant update\s*\(([\s\S]*?)\)\s*on (?:table )?public\.drivers',
    ).firstMatch(sql)?.group(1);
    expect(driverUpdateGrant, isNotNull);
    expect(driverUpdateGrant, contains('current_lat'));
    expect(driverUpdateGrant, contains('current_lng'));
    expect(driverUpdateGrant, contains('location_updated_at'));
    expect(driverUpdateGrant, contains('updated_at'));
    expect(driverUpdateGrant, isNot(contains('rating')));
    expect(driverUpdateGrant, isNot(contains('vehicle_type')));
  });

  test('provides role-scoped profile and return-origin RPCs', () {
    final sql = migrationSql();

    expect(sql, contains('function public.get_my_driver_account_profile'));
    expect(sql, contains('function public.get_support_return_driver_origin'));
    expect(sql, contains("when v_role = 'driver' then null"));
    expect(sql, contains("v_role in ('support', 'admin')"));
    expect(sql, contains('report.id = p_risk_report_id'));
    expect(sql, contains("set search_path = ''"));
  });

  test('prevents drivers from reading customer reviews about themselves', () {
    final sql = migrationSql();

    expect(sql, contains('drop policy if exists reviews_select_driver_own'));
    expect(sql, contains('create policy reviews_driver_authored_select'));
    expect(sql, contains("reviews.direction = 'driver_to_customer'"));
  });

  test('blocks driver self-service profile updates including role changes', () {
    final sql = migrationSql();

    expect(
      sql,
      contains('revoke update on table public.users from authenticated'),
    );
    expect(
      sql,
      contains('function public.reject_driver_direct_profile_update'),
    );
    expect(sql, contains("old.role = 'driver'::public.user_role"));
    expect(sql, contains('driver_profile_changes_require_admin_approval'));
    expect(sql, isNot(contains('grant update (role')));
  });
}
