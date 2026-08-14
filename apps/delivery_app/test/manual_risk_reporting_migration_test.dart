import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/'
    '202608110001_manual_order_risk_reporting.sql',
  );

  String allMigrationSql() => Directory('../../supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .map((file) => file.readAsStringSync())
      .join('\n')
      .toLowerCase();

  test(
    'participant report command derives identity and restricts ownership',
    () {
      final sql = migration.readAsStringSync().toLowerCase();

      expect(sql, contains('function public.create_participant_risk_report'));
      expect(sql, contains('actor_id uuid := (select auth.uid())'));
      expect(sql, contains("actor_role = 'customer'::public.user_role"));
      expect(sql, contains("actor_role = 'driver'::public.user_role"));
      expect(sql, contains('v_order.customer_id = actor_id'));
      expect(sql, contains('v_order.driver_id = actor_id'));
      expect(sql, contains("'medium'"));
      expect(sql, contains('security definer'));
      expect(sql, contains("set search_path = ''"));
      expect(sql, contains('from public, anon, authenticated, service_role'));
    },
  );

  test(
    'photo, location and message evidence are immutable and order scoped',
    () {
      final sql = migration.readAsStringSync().toLowerCase();

      expect(sql, contains('create table public.risk_report_attachments'));
      expect(sql, contains("evidence_type in ('photo', 'location')"));
      expect(sql, contains("'risk-report-evidence'"));
      expect(
        sql,
        contains("storage.foldername(name))[1] = (select auth.uid())::text"),
      );
      expect(
        sql,
        contains("storage.foldername(photo_path))[2] <> p_report_id::text"),
      );
      expect(sql, contains('message.order_id = p_order_id'));
      expect(sql, contains('insert into public.risk_report_message_evidence'));
      expect(
        sql,
        isNot(contains('grant update on public.risk_report_attachments')),
      );
      expect(
        sql,
        isNot(contains('grant delete on public.risk_report_attachments')),
      );
    },
  );

  test(
    'participants can read only reports and evidence tied to their order',
    () {
      final sql = migration.readAsStringSync().toLowerCase();

      expect(sql, contains('create policy risk_reports_participant_select'));
      expect(sql, contains('create policy risk_events_participant_select'));
      expect(
        sql,
        contains('create policy risk_attachments_participant_select'),
      );
      expect(
        sql,
        contains('create policy risk_message_evidence_participant_select'),
      );
      expect(sql, contains('report.reported_by = (select auth.uid())'));
    },
  );

  test(
    'uploader can read evidence metadata before attachment registration',
    () {
      final sql = allMigrationSql();
      final policy = RegExp(
        r'create policy risk_evidence_select_own_prefix[\s\S]*?;',
      ).firstMatch(sql)?.group(0);

      expect(policy, isNotNull);
      expect(policy, contains('on storage.objects'));
      expect(policy, contains('for select'));
      expect(policy, contains('to authenticated'));
      expect(policy, contains("bucket_id = 'risk-report-evidence'"));
      expect(
        policy,
        contains("storage.foldername(name))[1] = (select auth.uid())::text"),
      );
      expect(policy, contains('owner_id = (select auth.uid())::text'));
      expect(policy, isNot(contains('risk_report_attachments')));
    },
  );
}
