import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic dispatch filters drivers who cannot cover the advance', () {
    final migrations =
        Directory(
            '../../supabase/migrations',
          ).listSync().whereType<File>().where((file) {
            final sql = file.readAsStringSync().toLowerCase();
            return sql.contains(
              'create or replace function '
              'private.dispatch_next_order_offer_unbounded',
            );
          }).toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    expect(migrations, isNotEmpty);
    final sql = migrations.last.readAsStringSync().toLowerCase();
    final candidateStart = sql.indexOf('for candidate in');
    final candidateEnd = sql.indexOf('\n  loop', candidateStart);

    expect(candidateStart, greaterThanOrEqualTo(0));
    expect(candidateEnd, greaterThan(candidateStart));
    final candidateSql = sql.substring(candidateStart, candidateEnd);

    expect(candidateSql, contains('offer_order.driver_advance_amount'));
    expect(candidateSql, contains('public.driver_wallet_transactions'));
    expect(
      candidateSql,
      contains('wallet_tx.driver_id = driver_profile.user_id'),
    );
    expect(candidateSql, contains("wallet_tx.status = 'completed'"));
    expect(
      RegExp(
        r"coalesce\s*\(\s*\(\s*select\s+sum\(wallet_tx\.available_delta\)[\s\S]*?\),\s*0\s*\)\s*>=\s*offer_order\.driver_advance_amount",
      ).hasMatch(candidateSql),
      isTrue,
    );
  });
}
