import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/customer/screens/account/utils/customer_wallet_period.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/models/customer_payment.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/models/customer_payment_statistics.dart';

import 'helpers/customer_payment_fixtures.dart';

void main() {
  test(
    'completed totals exclude holds, refunds, pending and unsuccessful attempts',
    () {
      final statistics = CustomerPaymentStatistics([
        ...paymentFixtures(),
        paymentFixture(state: CustomerPaymentState.pending, amount: 999999),
        paymentFixture(state: CustomerPaymentState.failed, amount: 999999),
        paymentFixture(state: CustomerPaymentState.expired, amount: 999999),
        paymentFixture(state: CustomerPaymentState.reversed, amount: 999999),
      ]);
      expect(statistics.total, 280000);
      expect(statistics.methodTotal(CustomerPaymentMethod.wallet), 113000);
      expect(statistics.methodTotal(CustomerPaymentMethod.vnpay), 167000);
      expect(statistics.amount(CustomerPaymentState.refunded), 25000);
      expect(statistics.amount(CustomerPaymentState.reserved), 28000);
      expect(statistics.amount(CustomerPaymentState.refundPending), 46000);
    },
  );

  test(
    'chart buckets preserve the total and group instants by Vietnam date',
    () {
      final payments = [
        paymentFixture(date: DateTime.utc(2026, 10, 1, 16, 59)),
        paymentFixture(
          method: CustomerPaymentMethod.vnpay,
          date: DateTime.utc(2026, 10, 1, 17),
        ),
        paymentFixture(state: CustomerPaymentState.reserved, amount: 999999),
      ];
      final selection = CustomerWalletPeriodSelection(
        period: CustomerWalletPeriod.week,
        anchorDate: DateTime(2026, 10, 1),
      );
      final statistics = CustomerPaymentStatistics(payments);
      final buckets = statistics.buckets(selection);
      expect(buckets[3].amount, 35000);
      expect(buckets[4].amount, 35000);
      expect(
        buckets.fold(0, (total, bucket) => total + bucket.amount),
        statistics.total,
      );
      final month = statistics.buckets(
        selection.withPeriod(CustomerWalletPeriod.month),
      );
      expect(month, hasLength(7));
      expect(month.last.label, '31');
    },
  );

  test('method filtering changes totals and states together', () {
    final statistics = CustomerPaymentStatistics(
      paymentFixtures(),
      method: CustomerPaymentMethod.vnpay,
    );
    expect(statistics.total, 167000);
    expect(statistics.payments, hasLength(3));
    expect(statistics.amount(CustomerPaymentState.reserved), 0);
    expect(statistics.amount(CustomerPaymentState.refundPending), 46000);
  });

  test('wallet completed status needs a settled payment state', () {
    for (final pair in [
      ('reserved', CustomerPaymentState.reserved),
      ('settled', CustomerPaymentState.completed),
      ('refunded', CustomerPaymentState.refunded),
      (null, CustomerPaymentState.unknown),
    ]) {
      final row = paymentFixture().toJson()
        ..['metadata'] = {'payment_state': pair.$1};
      expect(
        CustomerPayment.fromJson(row, CustomerPaymentMethod.wallet).state,
        pair.$2,
      );
    }
    final reversed = paymentFixture().toJson()..['status'] = 'reversed';
    expect(
      CustomerPayment.fromJson(reversed, CustomerPaymentMethod.wallet).state,
      CustomerPaymentState.reversed,
    );
  });
}
