import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Online PIN is stored on drivers and enforced by the atomic command',
    () {
      final migrations = Directory('../../supabase/migrations')
          .listSync()
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('_driver_online_pin_verification.sql'),
          )
          .toList();

      expect(migrations, hasLength(1));
      final sql = migrations.single.readAsStringSync().toLowerCase();
      final normalizedSql = sql.replaceAll(RegExp(r'\s+'), ' ');

      expect(sql, contains('alter table public.drivers'));
      expect(sql, contains('online_pin_hash text'));
      expect(sql, contains("extensions.gen_salt('bf', 12)"));
      expect(sql, contains('extensions.crypt(p_pin, v_pin_hash)'));
      expect(sql, contains("p_pin ~ '^[0-9]{6}\$'"));
      expect(sql, contains("'status', 'invalid_pin'"));
      expect(sql, contains("'status', 'locked'"));
      expect(sql, contains("interval '5 minutes'"));
      expect(sql, contains('for update'));
      expect(
        normalizedSql,
        contains(
          'drop function public.set_driver_online_with_location( '
          'double precision, double precision );',
        ),
      );
      expect(
        normalizedSql,
        contains(
          'grant execute on function public.set_driver_online_with_location( '
          'double precision, double precision, text ) to authenticated;',
        ),
      );
      expect(sql, contains('driver_online_requires_pin_and_location'));
    },
  );
}
