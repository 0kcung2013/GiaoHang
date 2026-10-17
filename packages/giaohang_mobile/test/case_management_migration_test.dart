import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final foundation = File(
    '../../supabase/migrations/'
    '20260812164146_complete_case_management_demo.sql',
  );
  final commands = File(
    '../../supabase/migrations/'
    '20260812164159_case_management_commands.sql',
  );
  final operations = File(
    '../../supabase/migrations/'
    '20260812164214_case_management_realtime_stats.sql',
  );

  test('case conversations use RLS and narrow table privileges', () {
    final sql = foundation.readAsStringSync().toLowerCase();

    expect(sql, contains('create table public.support_ticket_messages'));
    expect(sql, contains('create table public.risk_report_messages'));
    expect(sql, contains('enable row level security'));
    expect(sql, contains('revoke all on public.support_ticket_messages'));
    expect(sql, contains('revoke update on public.support_tickets'));
    expect(sql, contains('revoke update on public.risk_reports'));
  });

  test('commands enforce ownership and customer reply reopening', () {
    final foundationSql = foundation.readAsStringSync().toLowerCase();
    final commandSql = commands.readAsStringSync().toLowerCase();

    expect(commandSql, contains('function public.accept_support_ticket'));
    expect(commandSql, contains('function public.takeover_support_ticket'));
    expect(commandSql, contains('function public.transition_risk_report'));
    expect(commandSql, contains('function public.post_risk_report_message'));
    expect(
      commandSql,
      contains('function public.convert_support_ticket_to_risk'),
    );
    expect(foundationSql, contains("old.status = 'waiting_customer'"));
    expect(commandSql, contains("set status = 'in_progress'"));
  });

  test('system incidents, realtime, SLA and server pagination are present', () {
    final foundationSql = foundation.readAsStringSync().toLowerCase();
    final operationsSql = operations.readAsStringSync().toLowerCase();

    expect(foundationSql, contains("scope = 'system'"));
    expect(foundationSql, contains('alter column order_id drop not null'));
    expect(operationsSql, contains('alter publication supabase_realtime'));
    expect(operationsSql, contains('function public.list_risk_reports_page'));
    expect(
      operationsSql,
      contains('function public.case_management_dashboard'),
    );
    expect(operationsSql, contains("'escalate-overdue-case-management'"));
  });
}
