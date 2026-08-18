import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  File migration(String suffix) {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith(suffix))
        .toList();
    expect(matches, hasLength(1));
    return matches.single;
  }

  String workflowSql() => [
    migration('_create_return_order_workflow.sql').readAsStringSync(),
    migration('_harden_return_order_transitions.sql').readAsStringSync(),
    migration('_create_return_order_commands.sql').readAsStringSync(),
    migration('_complete_return_order_commands.sql').readAsStringSync(),
    migration('_consolidate_order_return_select_policy.sql').readAsStringSync(),
    migration('_index_return_approval_actor.sql').readAsStringSync(),
  ].join('\n');

  test('return statuses are isolated in their own enum migration', () {
    final sql = migration('_add_return_order_statuses.sql').readAsStringSync();
    expect(sql, contains("ADD VALUE IF NOT EXISTS 'return_approved'"));
    expect(sql, contains("ADD VALUE IF NOT EXISTS 'returning'"));
    expect(sql, contains("ADD VALUE IF NOT EXISTS 'returned'"));
    expect(sql, isNot(contains('CREATE TABLE')));
  });

  test('workflow creates an RLS protected return record', () {
    final sql = workflowSql();
    expect(sql, contains('CREATE TABLE public.order_returns'));
    expect(
      sql,
      contains('ALTER TABLE public.order_returns ENABLE ROW LEVEL SECURITY'),
    );
    expect(
      sql,
      contains('REVOKE INSERT, UPDATE, DELETE ON public.order_returns'),
    );
    expect(
      sql,
      contains('DROP POLICY IF EXISTS order_returns_participant_select'),
    );
    expect(sql, contains('DROP POLICY IF EXISTS order_returns_staff_select'));
    expect(sql, contains('CREATE POLICY order_returns_related_select'));
    expect(sql, contains('CREATE INDEX order_returns_approved_by_idx'));
  });

  test('workflow commands are atomic restricted and idempotent', () {
    final sql = workflowSql();
    expect(sql, contains('FUNCTION public.support_approve_return'));
    expect(sql, contains('FUNCTION public.start_order_return'));
    expect(sql, contains('FUNCTION public.confirm_order_return'));
    expect(sql, contains("SET search_path = ''"));
    expect(sql, contains('FROM PUBLIC, anon'));
    expect(sql, contains('ON CONFLICT (idempotency_key) DO NOTHING'));
    expect(sql, contains('RETURN_WORKFLOW_REQUIRED'));
    expect(sql, isNot(contains('tokens truncated')));
  });

  test('phase 1 return fee is paid by platform only', () {
    final sql = workflowSql();
    expect(sql, contains("p_fee_payer <> 'platform'"));
    expect(sql, contains('RETURN_CUSTOMER_CHARGE_NOT_SUPPORTED'));
    expect(sql, contains("'waived'"));
  });

  test('return completion requires proof geofence and settles driver', () {
    final sql = workflowSql();
    expect(sql, contains("proof.stage = 'return'"));
    expect(sql, contains('RETURN_PROOF_REQUIRED'));
    expect(sql, contains('RETURN_OUTSIDE_GEOFENCE'));
    expect(sql, contains("'return_earning'"));
    expect(sql, contains("status = 'returned'"));
    final confirmFunction = sql
        .split('CREATE OR REPLACE FUNCTION public.confirm_order_return')[1]
        .split(
          'CREATE OR REPLACE FUNCTION public.confirm_risk_custody_resolved',
        )[0];
    expect(
      confirmFunction,
      isNot(contains("status = 'cancelled'::public.order_status")),
    );
  });

  test(
    'active return keeps the report actionable and completion compatible',
    () {
      final sql = migration(
        '_preserve_active_return_risk_status.sql',
      ).readAsStringSync();

      expect(
        sql,
        contains("OLD.status IN ('investigating', 'action_required')"),
      );
      expect(sql, contains("intervention.state = 'return_required'"));
      expect(sql, contains("NEW.status <> 'action_required'"));
      expect(sql, contains('RETURN_REPORT_STATUS_LOCKED'));
    },
  );
}
