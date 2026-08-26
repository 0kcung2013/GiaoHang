import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dispatch offer compares timestamps using a non-keyword variable', () {
    final migrations =
        Directory(
            '../../supabase/migrations',
          ).listSync().whereType<File>().toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    final definitions = migrations
        .map((file) => file.readAsStringSync())
        .where(
          (sql) => sql.contains('FUNCTION private.dispatch_next_order_offer'),
        )
        .toList();

    expect(definitions, isNotEmpty);
    final latestDefinition = definitions.last;

    expect(
      latestDefinition,
      contains('v_now timestamptz := clock_timestamp()'),
    );
    expect(
      latestDefinition,
      contains('offer_order.assignment_expires_at <= v_now'),
    );
    expect(
      latestDefinition,
      isNot(contains('current_time timestamptz := clock_timestamp()')),
    );
  });
}
