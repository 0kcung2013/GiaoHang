import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    final files = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('_limit_free_pick_radius_to_four_km.sql'),
        )
        .toList();

    expect(files, hasLength(1));
    sql = files.single.readAsStringSync();
  });

  test('limits both FreePick RPCs to four kilometers', () {
    expect(
      RegExp(r'FUNCTION public\.get_free_pick_orders_in_view').hasMatch(sql),
      isTrue,
    );
    expect(
      RegExp(r'FUNCTION public\.claim_free_pick_order').hasMatch(sql),
      isTrue,
    );
    expect(RegExp(r'\n\s*4000\n').allMatches(sql), hasLength(2));
    expect(sql, isNot(contains('50000')));
  });

  test('claim rejects orders outside the authoritative radius', () {
    expect(sql, contains("RAISE EXCEPTION 'FREE_PICK_OUT_OF_RANGE'"));
    expect(sql, contains('FOR UPDATE'));
    expect(sql, contains('public.accept_order(p_order_id)'));
  });

  test('keeps both RPCs restricted to authenticated users', () {
    expect(
      RegExp(
        r'REVOKE ALL ON FUNCTION public\.get_free_pick_orders_in_view',
      ).hasMatch(sql),
      isTrue,
    );
    expect(
      RegExp(
        r'GRANT EXECUTE ON FUNCTION public\.get_free_pick_orders_in_view',
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
        r'GRANT EXECUTE ON FUNCTION public\.claim_free_pick_order',
      ).hasMatch(sql),
      isTrue,
    );
  });
}
