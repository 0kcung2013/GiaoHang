import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith(
            '_exclude_persistent_demo_orders_from_dispatch.sql',
          ),
        )
        .toList();
    expect(matches, hasLength(1));
    sql = matches.single.readAsStringSync();
  });

  test('persistent FreePick demo bypasses the automatic offer cycle', () {
    final demoGuard = sql.indexOf(
      "COALESCE(offer_order.note, '') = 'FREEPICK_DEMO_PERSISTENT'",
    );
    final normalDispatch = sql.indexOf(
      "excluded_drivers := COALESCE(offer_order.rejected_by, '[]'::jsonb)",
    );

    expect(demoGuard, greaterThanOrEqualTo(0));
    expect(normalDispatch, greaterThan(demoGuard));
    expect(sql, contains('SET offered_driver_id = NULL'));
    expect(sql, contains('offer_expires_at = NULL'));
  });

  test('migration changes only the private dispatcher', () {
    expect(sql, contains('FUNCTION private.dispatch_next_order_offer'));
    expect(
      sql,
      isNot(contains('FUNCTION public.get_free_pick_orders_in_view')),
    );
    expect(sql, isNot(contains('FUNCTION public.claim_free_pick_order')));
  });
}
