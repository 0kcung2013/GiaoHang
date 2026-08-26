import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('going online with fresh GPS wakes eligible waiting orders', () {
    final migrations = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith(
            '_redispatch_waiting_orders_on_driver_online.sql',
          ),
        )
        .toList();

    expect(migrations, hasLength(1));
    final sql = migrations.single.readAsStringSync().toLowerCase();

    expect(
      sql,
      contains(
        'create or replace function '
        'public.set_driver_online_with_location',
      ),
    );
    expect(sql, contains('current_lat = p_lat'));
    expect(sql, contains('current_lng = p_lng'));
    expect(sql, contains('v_now timestamptz := clock_timestamp()'));
    expect(sql, contains('location_updated_at = v_now'));
    expect(sql, contains('is_available = true'));
    expect(sql, contains('private.dispatch_waiting_orders_for_driver'));
    expect(sql, contains('order by waiting_order.created_at asc'));
    expect(sql, contains('assignment_expires_at > clock_timestamp()'));
    expect(sql, contains('private.dispatch_next_order_offer('));
    expect(sql, contains('limit 20'));

    final normalizedSql = sql.replaceAll(RegExp(r'\s+'), ' ');
    expect(
      normalizedSql,
      contains(
        'revoke all on function public.set_driver_online_with_location( '
        'double precision, double precision ) from public, anon;',
      ),
    );
    expect(
      normalizedSql,
      contains(
        'grant execute on function public.set_driver_online_with_location( '
        'double precision, double precision ) to authenticated;',
      ),
    );
  });
}
