import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/'
    '202608110004_allow_driver_risk_custody_release.sql',
  );
  final driverPolicy = File(
    '../../supabase/migrations/'
    '202606010003_add_driver_order_status_progression_policy.sql',
  );

  test(
    'driver progression trigger permits only an authorized custody release',
    () {
      final sql = migration.readAsStringSync().toLowerCase();

      expect(
        sql,
        contains('function public.enforce_driver_order_status_progression'),
      );
      expect(sql, contains('risk_report_interventions as intervention'));
      expect(sql, contains('intervention.driver_id = actor_id'));
      expect(sql, contains("intervention.state = 'return_required'"));
      expect(sql, contains("new.status = 'cancelled'::public.order_status"));
      expect(sql, contains("intervention.state = 'handoff_required'"));
      expect(sql, contains("new.status = 'risk_hold'::public.order_status"));
      expect(sql, contains('new.driver_id is null'));
      expect(sql, contains('return new'));
    },
  );

  test('normal driver updates retain the original one-step restrictions', () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(
      sql,
      contains(
        "old.status = 'assigned'::public.order_status "
        "and new.status = 'picking_up'::public.order_status",
      ),
    );
    expect(
      sql,
      contains(
        "old.status = 'picking_up'::public.order_status "
        "and new.status = 'delivering'::public.order_status",
      ),
    );
    expect(
      sql,
      contains(
        "old.status = 'delivering'::public.order_status "
        "and new.status = 'delivered'::public.order_status",
      ),
    );
    expect(sql, contains('drivers may only update order status fields'));
    expect(sql, contains('invalid driver order status transition'));
  });

  test('RLS prevents direct driver custody release transitions', () {
    final sql = driverPolicy.readAsStringSync().toLowerCase();

    expect(sql, contains('with check'));
    expect(sql, contains("'delivered'::public.order_status"));
    expect(sql, isNot(contains("'cancelled'::public.order_status")));
    expect(sql, isNot(contains("'risk_hold'::public.order_status")));
  });
}
