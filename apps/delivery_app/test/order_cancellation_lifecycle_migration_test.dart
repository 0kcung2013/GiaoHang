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

  test('customer cancellation ignores pickup proofs from a previous driver', () {
    final migration = File(
      '../../supabase/migrations/20260913120000_fix_customer_cancel_pickup_proof_owner.sql',
    ).readAsStringSync();

    expect(migration, contains('proof.driver_id = v_order.driver_id'));
    expect(migration, contains("proof.stage = 'pickup'"));
    expect(migration, contains('ORDER_ALREADY_PICKED_UP'));
  });
}
