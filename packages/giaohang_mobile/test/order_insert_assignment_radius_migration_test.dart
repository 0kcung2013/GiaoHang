import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrations =
      Directory(
          '../../supabase/migrations',
        ).listSync().whereType<File>().toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  test('new orders dispatch their first automatic offer within two km', () {
    final definitions = migrations
        .map((file) => file.readAsStringSync())
        .where(
          (sql) => sql.contains(
            'FUNCTION private.dispatch_order_offer_after_insert',
          ),
        )
        .toList();

    expect(definitions, isNotEmpty);
    final latestDefinition = definitions.last;
    expect(
      latestDefinition,
      contains('private.dispatch_next_order_offer(NEW.id, 2000)'),
    );
    expect(
      latestDefinition,
      isNot(contains('private.dispatch_next_order_offer(NEW.id, 5000)')),
    );
  });

  test('automatic offer dispatcher cannot expand beyond two km', () {
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
      contains('p_radius_meters double precision DEFAULT 2000'),
    );
    expect(
      latestDefinition,
      contains('LEAST(GREATEST(p_radius_meters, 1), 2000)'),
    );
    expect(
      latestDefinition,
      isNot(contains('LEAST(GREATEST(p_radius_meters, 1), 50000)')),
    );
  });
}
