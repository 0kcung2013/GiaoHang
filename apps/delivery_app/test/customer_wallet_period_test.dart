import 'package:delivery_app/core/models/customer_wallet.dart';
import 'package:delivery_app/features/customer/screens/account/utils/customer_wallet_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final transactions = [
    CustomerWalletTransaction(
      id: 'today-credit',
      type: 'delivery_credit',
      amount: 300000,
      availableDelta: 300000,
      createdAt: DateTime.utc(2026, 9, 3, 2),
    ),
    CustomerWalletTransaction(
      id: 'week-debit',
      type: 'adjustment_debit',
      amount: 50000,
      availableDelta: -50000,
      createdAt: DateTime.utc(2026, 9, 1, 2),
    ),
    CustomerWalletTransaction(
      id: 'previous-month-credit',
      type: 'risk_credit',
      amount: 200000,
      availableDelta: 200000,
      createdAt: DateTime.utc(2026, 8, 25, 2),
    ),
  ];

  test('filters customer wallet transactions by day, week and month', () {
    final day = CustomerWalletPeriodSelection(
      period: CustomerWalletPeriod.day,
      anchorDate: DateTime(2026, 9, 3),
    );
    final week = day.withPeriod(CustomerWalletPeriod.week);
    final month = day.withPeriod(CustomerWalletPeriod.month);

    expect(day.filter(transactions).map((item) => item.id), ['today-credit']);
    expect(week.filter(transactions).map((item) => item.id), [
      'today-credit',
      'week-debit',
    ]);
    expect(month.filter(transactions).map((item) => item.id), [
      'today-credit',
      'week-debit',
    ]);
  });

  test('calculates money in and out for the selected period', () {
    final selection = CustomerWalletPeriodSelection(
      period: CustomerWalletPeriod.week,
      anchorDate: DateTime(2026, 9, 3),
    );
    final filtered = selection.filter(transactions);

    expect(selection.received(filtered), 300000);
    expect(selection.spent(filtered), 50000);
  });

  test('moves between calendar periods without changing the selected mode', () {
    final selection = CustomerWalletPeriodSelection(
      period: CustomerWalletPeriod.month,
      anchorDate: DateTime(2026, 9, 3),
    );

    final previous = selection.shift(-1);

    expect(previous.period, CustomerWalletPeriod.month);
    expect(previous.start, DateTime(2026, 8));
    expect(previous.endExclusive, DateTime(2026, 9));
  });
}
