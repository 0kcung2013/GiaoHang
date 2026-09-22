import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      '../../supabase/migrations/20260917050646_enforce_single_active_session.sql',
    ).readAsStringSync();
  });

  test('reuses users table for the active session marker', () {
    expect(migration, contains('alter table public.users'));
    expect(migration, contains('active_session_id uuid'));
    expect(migration, contains('active_session_updated_at timestamptz'));
    expect(migration, isNot(contains('create table')));
  });

  test('claims only the authenticated JWT session', () {
    expect(migration, contains('auth.uid()'));
    expect(migration, contains("auth.jwt() ->> 'session_id'"));
    expect(migration, contains('where id = current_user_id'));
    expect(
      migration,
      contains(
        'revoke all on function public.claim_active_session() from public',
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.claim_active_session() to authenticated',
      ),
    );
  });

  test('publishes users changes to Supabase Realtime once', () {
    expect(migration, contains("pubname = 'supabase_realtime'"));
    expect(
      migration,
      contains('alter publication supabase_realtime add table public.users'),
    );
  });
}
