import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String migrationSql() {
    final files = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith('_driver_profile_request_storage.sql'),
        )
        .toList();
    expect(files, hasLength(1));
    return files.single.readAsStringSync().toLowerCase();
  }

  test('keeps draft files private and Admin-reviewed', () {
    final sql = migrationSql();

    expect(sql, contains("'driver-profile-request-files'"));
    expect(sql, contains("'driver-avatars'"));
    expect(sql, contains('public, file_size_limit, allowed_mime_types'));
    expect(sql, contains("bucket_id = 'driver-profile-request-files'"));
    expect(sql, contains("request.status = 'draft'"));
    expect(sql, contains("actor.role = 'admin'::public.user_role"));
    expect(sql, isNot(contains("actor.role = 'support'::public.user_role")));
  });

  test('enforces the user request and file path shape', () {
    final sql = migrationSql();

    expect(
      sql,
      contains("(storage.foldername(name))[1] = (select auth.uid())::text"),
    );
    expect(sql, contains("request.id::text = (storage.foldername(name))[2]"));
    expect(sql, contains('array_length(storage.foldername(name), 1) = 2'));
  });

  test('internal approval commands are service-role only', () {
    final sql = migrationSql();

    for (final command in [
      'prepare_driver_profile_change_approval',
      'finalize_driver_profile_change_approval',
      'rollback_driver_profile_change_approval',
    ]) {
      expect(sql, contains('function public.$command'));
      expect(sql, contains('grant execute on function public.$command'));
    }
    expect(sql, contains('from public, anon, authenticated'));
    expect(sql, contains('to service_role'));
    expect(sql, contains("set search_path = ''"));
  });

  test('prepare rechecks Admin role snapshot and pending state', () {
    final sql = migrationSql();

    expect(sql, contains("v_request.status <> 'pending'"));
    expect(sql, contains("status = 'applying'"));
    expect(sql, contains("status = 'conflicted'"));
    expect(sql, contains('p_admin_id'));
    expect(sql, contains('current_snapshot'));
  });
}
