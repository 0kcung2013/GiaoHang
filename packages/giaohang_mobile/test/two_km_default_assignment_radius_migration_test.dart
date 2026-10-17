import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default assignment and retry use the 2 km radius', () {
    final matches = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('_set_two_km_default_assignment_radius.sql'),
        )
        .toList();

    expect(matches, hasLength(1));
    final sql = matches.single.readAsStringSync();
    expect(
      RegExp(r'p_radius_meters double precision DEFAULT 2000').allMatches(sql),
      hasLength(1),
    );
    expect(sql, contains('radius_meters double precision DEFAULT 2000'));
    expect(sql, contains('LEAST(GREATEST(p_radius_meters, 1), 2000)'));
    expect(
      sql,
      contains('PERFORM private.dispatch_next_order_offer(p_order_id, 2000)'),
    );
    expect(
      RegExp(r'FREE_PICK_INSIDE_DEFAULT_RADIUS').allMatches(sql),
      hasLength(1),
    );
    expect(
      RegExp(r'NOT public\.ST_DWithin\(').allMatches(sql).length,
      greaterThanOrEqualTo(1),
    );
  });
}
