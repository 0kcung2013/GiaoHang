import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  test(
    'picking_up does not imply custody without explicit pickup confirmation',
    () {
      final order = RiskOrderSummary.fromJson({'status': 'picking_up'});
      expect(order.hasPickedUp, isFalse);
      final confirmed = RiskOrderSummary.fromJson({
        'status': 'picking_up',
        'actual_picked_up_at': '2026-10-08T06:00:00Z',
      });
      expect(confirmed.hasPickedUp, isTrue);
      expect(
        RiskOrderSummary.fromJson(confirmed.toJson()).actualPickedUpAt,
        confirmed.actualPickedUpAt,
      );
    },
  );
  test(
    'legacy delivering orders remain protected without a pickup timestamp',
    () {
      expect(
        RiskOrderSummary.fromJson({'status': 'delivering'}).hasPickedUp,
        isTrue,
      );
    },
  );
}
