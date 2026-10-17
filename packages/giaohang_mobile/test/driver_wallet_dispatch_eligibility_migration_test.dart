import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('road dispatch filters drivers who cannot cover the advance', () {
    final migrations =
        Directory(
            '../../supabase/migrations',
          ).listSync().whereType<File>().where((file) {
            final sql = file.readAsStringSync().toLowerCase();
            return sql.contains(
              'create or replace function '
              'private.road_driver_candidates',
            );
          }).toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    expect(migrations, isNotEmpty);
    final sql = migrations.last.readAsStringSync().toLowerCase();
    final candidateStart = sql.indexOf(
      'from public.orders o cross join public.drivers d',
    );
    expect(candidateStart, greaterThanOrEqualTo(0));
    final candidateEnd = sql.indexOf('\n\$fn\$;', candidateStart);
    expect(candidateEnd, greaterThan(candidateStart));
    final candidateSql = sql.substring(candidateStart, candidateEnd);

    expect(candidateSql, contains('o.driver_advance_amount'));
    expect(candidateSql, contains('public.driver_wallet_transactions'));
    expect(candidateSql, contains('w.driver_id = d.user_id'));
    expect(candidateSql, contains("w.status = 'completed'"));
    expect(
      RegExp(
        r"coalesce\s*\(\s*\(\s*select\s+sum\(w\.available_delta\)[\s\S]*?\),\s*0\s*\)\s*>=\s*o\.driver_advance_amount",
      ).hasMatch(candidateSql),
      isTrue,
    );
  });
}
