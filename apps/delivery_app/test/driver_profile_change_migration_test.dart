import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  File migration() {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith('_driver_profile_change_requests.sql'),
        )
        .toList();

    expect(matches, hasLength(1));
    return matches.single;
  }

  String migrationSql() => migration()
      .readAsStringSync()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  test('creates the request aggregate and its seven lifecycle states', () {
    final sql = migrationSql();

    expect(sql, contains('create table public.driver_profile_change_requests'));
    for (final status in [
      'draft',
      'pending',
      'applying',
      'approved',
      'rejected',
      'cancelled',
      'conflicted',
    ]) {
      expect(sql, contains("'$status'"));
    }
    expect(sql, contains("where status in ('draft', 'pending', 'applying')"));
  });

  test('exposes only read access and routes every write through commands', () {
    final sql = migrationSql();

    expect(
      sql,
      contains(
        'alter table public.driver_profile_change_requests enable row level security',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.driver_profile_change_requests from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant select on table public.driver_profile_change_requests to authenticated',
      ),
    );
    expect(sql, isNot(contains('grant insert on table')));
    expect(sql, isNot(contains('grant update on table')));
    expect(sql, isNot(contains('grant delete on table')));

    for (final command in [
      'create_driver_profile_change_draft',
      'submit_driver_profile_change_request',
      'cancel_driver_profile_change_request',
      'approve_driver_profile_change_request',
      'reject_driver_profile_change_request',
    ]) {
      expect(sql, contains('function public.$command'));
    }
    expect(sql, contains('security definer'));
    expect(sql, contains("set search_path = ''"));
    expect(sql, contains('from public, anon'));
  });

  test('keeps driver and admin visibility separate from support', () {
    final sql = migrationSql();

    expect(sql, contains('create policy driver_profile_changes_driver_select'));
    expect(sql, contains('requested_by = (select auth.uid())'));
    expect(sql, contains('create policy driver_profile_changes_admin_select'));
    expect(sql, contains("role = 'admin'::public.user_role"));
    expect(sql, contains("status <> 'draft'"));
    expect(sql, isNot(contains("role = 'support'::public.user_role")));
  });

  test(
    'approval is whole-request, conflict-aware and excludes auth fields',
    () {
      final sql = migrationSql();

      expect(sql, contains("v_request.status <> 'pending'"));
      expect(sql, contains("status = 'applying'"));
      expect(sql, contains("status = 'conflicted'"));
      expect(sql, contains("status = 'approved'"));
      expect(sql, contains("requested_changes ? 'email'"));
      expect(sql, contains("requested_changes ? 'avatar_path'"));
      expect(sql, contains('requires_edge_function'));
    },
  );

  test(
    'submission validates private upload ownership and derives snapshot',
    () {
      final sql = migrationSql();

      expect(
        sql,
        contains(
          "(select auth.uid())::text || '/' || p_request_id::text || '/'",
        ),
      );
      expect(sql, contains('current_snapshot = v_snapshot'));
      expect(sql, contains('requested_changes = v_changes'));
      expect(sql, contains('no_profile_changes'));
    },
  );
}
