import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pickup proof locks customer cancellation before the delivery status change',
    () {
      final migration = File(
        '../../supabase/migrations/20260807083427_driver_pickup_locks_cancellation.sql',
      ).readAsStringSync();

      expect(migration, contains("v_order.status = 'picking_up'"));
      expect(migration, contains("stage = 'pickup'"));
      expect(migration, contains('ORDER_ALREADY_PICKED_UP'));
    },
  );
}
