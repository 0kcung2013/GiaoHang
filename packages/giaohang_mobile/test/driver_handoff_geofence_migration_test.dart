import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driver handoffs are rejected outside the 100 m geofence', () {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith('_enforce_driver_handoff_geofence.sql'),
        )
        .toList();

    expect(matches, hasLength(1));
    final sql = matches.single.readAsStringSync();

    expect(
      sql,
      contains(
        'CREATE OR REPLACE FUNCTION private.enforce_driver_handoff_geofence()',
      ),
    );
    expect(sql, contains("handoff_stage := 'pickup'"));
    expect(sql, contains("handoff_stage := 'delivery'"));
    expect(sql, contains('proof.captured_lat IS NULL'));
    expect(sql, contains('proof.captured_lng IS NULL'));
    expect(sql, contains('public.ST_DWithin('));
    expect(sql, contains('100'));
    expect(sql, contains('PICKUP_OUTSIDE_GEOFENCE'));
    expect(sql, contains('DELIVERY_OUTSIDE_GEOFENCE'));
    expect(
      sql,
      contains(
        'CREATE TRIGGER enforce_driver_handoff_geofence_before_status_update',
      ),
    );
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION private.enforce_driver_handoff_geofence()',
      ),
    );
  });
}
