import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/'
    '20260804090214_simplify_driver_offer_distance.sql',
  );
  final redisFunction = File(
    '../../supabase/functions/find-nearest-drivers-redis/index.ts',
  );
  final assignmentEncodingMigration = File(
    '../../supabase/migrations/'
    '20260804090610_fix_driver_assignment_log_encoding.sql',
  );
  final rejectedDriverReofferMigration = File(
    '../../supabase/migrations/'
    '20260804091808_allow_rejected_driver_to_reoffer_order.sql',
  );
  final customerOnlyAssignmentMigration = File(
    '../../supabase/migrations/'
    '20260804092219_restore_customer_only_assignment_authorization.sql',
  );

  test('selects the nearest remaining driver after rejections', () {
    final sql = migration.readAsStringSync();
    final assignmentStart = sql.indexOf(
      'CREATE OR REPLACE FUNCTION public.assign_order_to_nearest_driver',
    );
    final lookupSql = sql.substring(0, assignmentStart);
    final assignmentSql = sql.substring(assignmentStart);

    expect(lookupSql, contains('FUNCTION public.find_nearest_drivers'));
    expect(lookupSql, contains("now() - interval '3 minutes'"));
    expect(lookupSql, isNot(contains('nearest_distance AS')));
    expect(lookupSql, contains('candidate.distance_meters ASC'));
    expect(lookupSql, contains('radius_meters double precision DEFAULT 5000'));
    expect(lookupSql, contains('public.ST_Distance'));
    expect(lookupSql, contains('public.ST_DWithin'));

    expect(assignmentSql, contains('eligible_candidates AS'));
    expect(assignmentSql, isNot(contains('nearest_remaining AS')));
    expect(assignmentSql, isNot(contains('nearest.v_min_distance + 100')));
    expect(assignmentSql, isNot(contains('candidate.rating DESC')));
    expect(assignmentSql, contains('candidate.distance_meters ASC'));
    expect(assignmentSql, contains('candidate.user_id ASC'));
    expect(
      assignmentSql,
      contains('p_radius_meters double precision DEFAULT 5000'),
    );
  });

  test('assigns the order and status log inside one database transaction', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('FUNCTION public.assign_order_to_nearest_driver'));
    expect(sql, contains('FOR UPDATE'));
    expect(sql, contains('UPDATE public.orders'));
    expect(sql, contains('INSERT INTO public.order_status_logs'));
    expect(sql, contains('WHEN unique_violation THEN'));
    expect(sql, contains('orders_one_active_per_driver_idx'));
    expect(sql, isNot(contains('%.')));
    expect(sql, contains("rating %s)."));
  });

  test('hardens execution privileges for assignment functions', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains("SECURITY DEFINER\nSET search_path = ''"));
    expect(
      RegExp(
        r'REVOKE ALL ON FUNCTION[\s\S]+?FROM PUBLIC, anon;',
      ).allMatches(sql),
      hasLength(2),
    );
    expect(
      RegExp(
        r'GRANT EXECUTE ON FUNCTION[\s\S]+?TO authenticated;',
      ).allMatches(sql),
      hasLength(2),
    );
  });

  test('returns Redis candidates ordered only by distance', () {
    final source = redisFunction.readAsStringSync();

    expect(source, contains('body.radius_meters ?? 2000'));
    expect(source, contains('Math.min(radius, 50000)'));
    expect(source, isNot(contains('nearestDistance + 100')));
    expect(source, isNot(contains('Number(right.rating)')));
    expect(
      source,
      contains('Number(left.distance_meters) - Number(right.distance_meters)'),
    );
    expect(source, contains('String(left.user_id).localeCompare'));
    expect(source, isNot(contains('"COUNT",\n      maxResults')));
  });

  test('keeps the assignment status log in valid Vietnamese', () {
    final sql = assignmentEncodingMigration.readAsStringSync();

    expect(sql, contains("'Đã phân công tài xế'"));
    expect(sql, contains("'Hệ thống phân công tài xế gần nhất (%s m).'"));
    expect(sql, isNot(contains('rating')));
  });

  test('lets only a rejected driver trigger the next server-side offer', () {
    final sql = rejectedDriverReofferMigration.readAsStringSync();

    expect(sql, contains('v_actor_is_rejected_driver boolean'));
    expect(sql, contains('FROM public.drivers driver_profile'));
    expect(sql, contains("? v_actor_id::text"));
    expect(
      sql,
      contains(
        'v_actor_id IS DISTINCT FROM v_order.customer_id\n'
        '     AND NOT v_actor_is_rejected_driver',
      ),
    );
    expect(sql, isNot(contains('p_driver_user_id')));
  });

  test('keeps the final assignment RPC authorization customer-only', () {
    final sql = customerOnlyAssignmentMigration.readAsStringSync();

    expect(sql, contains('v_actor_id IS DISTINCT FROM v_order.customer_id'));
    expect(sql, isNot(contains('v_actor_is_rejected_driver')));
    expect(sql, isNot(contains('p_driver_user_id')));
    expect(sql, contains('candidate.distance_meters ASC'));
  });
}
