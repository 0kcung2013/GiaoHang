import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final enumMigration = File(
    '../../supabase/migrations/202608110002_add_risk_hold_status.sql',
  );
  final workflowMigration = File(
    '../../supabase/migrations/202608110003_risk_report_interventions.sql',
  );
  final assignmentMigration = File(
    '../../supabase/migrations/'
    '20260804092219_restore_customer_only_assignment_authorization.sql',
  );

  test('risk hold enum is committed before workflow functions use it', () {
    final enumSql = enumMigration.readAsStringSync().toLowerCase();
    final workflowSql = workflowMigration.readAsStringSync().toLowerCase();

    expect(enumSql, contains("add value if not exists 'risk_hold'"));
    expect(enumSql, isNot(contains('update public.orders')));
    expect(workflowSql, contains("'risk_hold'::public.order_status"));
  });

  test('pre-pickup hold atomically releases the assigned driver', () {
    final sql = workflowMigration.readAsStringSync().toLowerCase();

    expect(sql, contains('function public.hold_risk_order_before_pickup'));
    expect(sql, contains('for update'));
    expect(sql, contains("v_order.status <> 'assigned'::public.order_status"));
    expect(sql, contains("status = 'risk_hold'::public.order_status"));
    expect(sql, contains('driver_id = null'));
    expect(sql, contains("state = 'held_before_pickup'"));
    expect(sql, contains('driver_released_at = now()'));
  });

  test('cargo custody must be resolved before the driver is released', () {
    final sql = workflowMigration.readAsStringSync().toLowerCase();

    expect(sql, contains('function public.decide_risk_delivery_operation'));
    expect(sql, contains("'return_required'"));
    expect(sql, contains("'handoff_required'"));
    expect(sql, contains('function public.confirm_risk_custody_resolved'));
    expect(sql, contains('intervention.driver_id = actor_id'));
    expect(sql, contains("state = 'released'"));
    expect(sql, contains('driver_released_at = now()'));
  });

  test('triage, participant reads and internal notes use narrow privileges', () {
    final sql = workflowMigration.readAsStringSync().toLowerCase();

    expect(sql, contains('create table public.risk_report_interventions'));
    expect(sql, contains('create table public.risk_report_notes'));
    expect(sql, contains('create policy risk_interventions_participant_select'));
    expect(sql, contains('create policy risk_notes_staff_select'));
    expect(sql, contains('function public.add_risk_report_note'));
    expect(sql, contains('function private.escalate_overdue_risk_triage'));
    expect(sql, contains("state = 'awaiting_triage'"));
    expect(sql, contains('escalated_at = now()'));
    expect(sql, contains('from public, anon, authenticated, service_role'));
  });

  test('held orders remain outside normal assignment discovery', () {
    final workflowSql = workflowMigration.readAsStringSync().toLowerCase();
    final assignmentSql = assignmentMigration.readAsStringSync().toLowerCase();

    expect(workflowSql, contains("status = 'risk_hold'::public.order_status"));
    expect(workflowSql, contains("status = 'confirmed'::public.order_status"));
    expect(assignmentSql, contains("'pending'::public.order_status"));
    expect(assignmentSql, contains("'confirmed'::public.order_status"));
    expect(assignmentSql, isNot(contains("'risk_hold'::public.order_status")));
  });
}
