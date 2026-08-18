import 'package:delivery_app/core/models/driver_wallet.dart';
import 'package:delivery_app/features/driver/screens/earnings/utils/driver_wallet_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final transactions = [
    _transaction('before', '2026-08-16T16:59:00Z', 9000),
    _transaction('start', '2026-08-16T17:00:00Z', 12000),
    _transaction('later', '2026-08-17T08:30:00Z', 18000),
    _transaction('topup', '2026-08-17T09:00:00Z', 500000, type: 'vnpay_topup'),
  ];

  test('day filter follows Vietnam midnight instead of UTC midnight', () {
    final selection = DriverWalletPeriodSelection(
      period: DriverWalletPeriod.day,
      anchorDate: DateTime(2026, 8, 17),
    );

    final result = selection.filter(transactions);

    expect(result.map((item) => item.id), ['topup', 'later', 'start']);
    expect(selection.income(result), 30000);
  });

  test('week begins on Monday and month follows Vietnam calendar', () {
    final week = DriverWalletPeriodSelection(
      period: DriverWalletPeriod.week,
      anchorDate: DateTime(2026, 8, 20),
    );
    final month = DriverWalletPeriodSelection(
      period: DriverWalletPeriod.month,
      anchorDate: DateTime(2026, 8, 31),
    );

    expect(week.start, DateTime(2026, 8, 17));
    expect(week.endExclusive, DateTime(2026, 8, 24));
    expect(month.start, DateTime(2026, 8));
    expect(month.endExclusive, DateTime(2026, 9));
  });
}

DriverWalletTransaction _transaction(
  String id,
  String createdAt,
  int amount, {
  String type = 'prepaid_earning',
}) {
  return DriverWalletTransaction.fromJson({
    'id': id,
    'transaction_type': type,
    'status': 'completed',
    'amount': amount,
    'available_delta': amount,
    'held_delta': 0,
    'created_at': createdAt,
  });
}
