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
            '_guard_driver_off_during_active_delivery.sql',
          ),
        )
        .toList();
    expect(matches, hasLength(1));
    sql = matches.single.readAsStringSync();
  });

  test('approved drivers start offline', () {
    final approveDriver = _between(
      sql,
      'CREATE OR REPLACE FUNCTION public.approve_driver',
      'REVOKE ALL ON FUNCTION public.approve_driver',
    );

    expect(approveDriver, contains('is_available = false'));
    expect(approveDriver, contains("IS DISTINCT FROM 'admin'"));
  });

  test('availability RPC rejects offline while a delivery is active', () {
    final availability = _between(
      sql,
      'CREATE OR REPLACE FUNCTION public.set_driver_availability',
      'REVOKE ALL ON FUNCTION public.set_driver_availability',
    );

    expect(availability, contains('p_is_available = false'));
    expect(availability, contains('DRIVER_HAS_ACTIVE_ORDER'));
    for (final status in [
      'assigned',
      'picking_up',
      'delivering',
      'return_approved',
      'returning',
    ]) {
      expect(availability, contains("'$status'"));
    }
  });

  test('security definer RPCs are restricted to authenticated users', () {
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.approve_driver(uuid) '
        'FROM PUBLIC, anon;',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.approve_driver(uuid) '
        'TO authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.set_driver_availability(boolean) '
        'FROM PUBLIC, anon;',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.set_driver_availability(boolean) '
        'TO authenticated;',
      ),
    );
  });
}

String _between(String source, String start, String end) {
  return source.split(start)[1].split(end)[0];
}
