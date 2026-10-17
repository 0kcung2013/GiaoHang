import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    final files = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith(
            '_free_pick_viewport_and_three_km_assignment.sql',
          ),
        )
        .toList();
    expect(files, hasLength(1));
    sql = files.single.readAsStringSync();
  });

  test('changes every default assignment path to three kilometers', () {
    expect(
      RegExp(r'DEFAULT 3000').allMatches(sql).length,
      greaterThanOrEqualTo(3),
    );
    expect(sql, contains('dispatch_next_order_offer(p_order_id, 3000)'));
    expect(sql, isNot(contains('DEFAULT 5000')));
  });

  test('lists only eligible orders inside a bounded viewport', () {
    expect(sql, contains('FUNCTION public.get_free_pick_orders_in_view'));
    expect(sql, contains('pickup_lat BETWEEN p_south AND p_north'));
    expect(sql, contains('pickup_lng BETWEEN p_west AND p_east'));
    expect(sql, contains('offer_expires_at <= now()'));
    expect(sql, contains('LEAST(GREATEST(p_limit, 1), 50)'));
    expect(sql, contains('FREE_PICK_VIEWPORT_TOO_LARGE'));
  });

  test('claims atomically and reuses accept_order checks', () {
    expect(sql, contains('FUNCTION public.claim_free_pick_order'));
    expect(sql, contains('FOR UPDATE'));
    expect(sql, contains('FREE_PICK_ORDER_RESERVED'));
    expect(sql, contains('public.accept_order(p_order_id)'));
    expect(sql, contains('public.ST_DWithin'));
  });

  test('restricts both FreePick RPCs to authenticated users', () {
    expect(
      RegExp(
        r'REVOKE ALL ON FUNCTION public\.get_free_pick_orders_in_view',
      ).hasMatch(sql),
      isTrue,
    );
    expect(
      RegExp(
        r'REVOKE ALL ON FUNCTION public\.claim_free_pick_order',
      ).hasMatch(sql),
      isTrue,
    );
    expect(
      RegExp(
        r'GRANT EXECUTE ON FUNCTION public\.get_free_pick_orders_in_view',
      ).hasMatch(sql),
      isTrue,
    );
  });
}
