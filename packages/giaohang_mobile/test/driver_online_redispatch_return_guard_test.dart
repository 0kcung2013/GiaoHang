import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all automatic offers treat return missions as active work', () {
    final migrations = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('_block_online_redispatch_during_returns.sql'),
        )
        .toList();

    expect(migrations, hasLength(1));
    final sql = migrations.single.readAsStringSync().toLowerCase();

    expect(sql, contains('guard_offer_driver_active_return'));
    expect(sql, contains('before update of offered_driver_id'));
    expect(sql, contains("'return_approved'::public.order_status"));
    expect(sql, contains("'returning'::public.order_status"));
    expect(sql, contains("raise unique_violation"));
    expect(
      sql,
      contains(
        'create or replace function '
        'public.set_driver_online_with_location',
      ),
    );
  });
}
