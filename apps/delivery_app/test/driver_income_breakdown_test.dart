import 'package:delivery_app/core/models/driver_wallet.dart';
import 'package:delivery_app/features/driver/screens/earnings/utils/driver_income_breakdown.dart';
import 'package:delivery_app/features/driver/screens/earnings/utils/driver_wallet_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('week breakdown creates one bucket per weekday', () {
    final selection = DriverWalletPeriodSelection(
      period: DriverWalletPeriod.week,
      anchorDate: DateTime(2026, 8, 19),
    );
    final buckets = buildDriverIncomeBreakdown(
      selection: selection,
      transactions: [
        _income('monday', 75000, '2026-08-17T02:00:00Z'),
        _income('wednesday', 125000, '2026-08-19T03:00:00Z'),
        _topup('topup', 500000, '2026-08-19T04:00:00Z'),
      ],
    );

    expect(buckets.map((bucket) => bucket.label), [
      'T2',
      'T3',
      'T4',
      'T5',
      'T6',
      'T7',
      'CN',
    ]);
    expect(buckets.map((bucket) => bucket.amount), [
      75000,
      0,
      125000,
      0,
      0,
      0,
      0,
    ]);
  });

  test('month breakdown groups income into seven-day ranges', () {
    final selection = DriverWalletPeriodSelection(
      period: DriverWalletPeriod.month,
      anchorDate: DateTime(2026, 9, 18),
    );
    final buckets = buildDriverIncomeBreakdown(
      selection: selection,
      transactions: [
        _income('first-week', 40000, '2026-09-06T03:00:00Z'),
        _income('last-week', 90000, '2026-09-29T03:00:00Z'),
      ],
    );

    expect(buckets.map((bucket) => bucket.label), [
      '01–07',
      '08–14',
      '15–21',
      '22–28',
      '29–30',
    ]);
    expect(buckets.map((bucket) => bucket.amount), [40000, 0, 0, 0, 90000]);
  });
}

DriverWalletTransaction _income(String id, int amount, String createdAt) {
  return DriverWalletTransaction.fromJson({
    'id': id,
    'transaction_type': 'prepaid_earning',
    'status': 'completed',
    'amount': amount,
    'available_delta': amount,
    'held_delta': 0,
    'created_at': createdAt,
  });
}

DriverWalletTransaction _topup(String id, int amount, String createdAt) {
  return DriverWalletTransaction.fromJson({
    'id': id,
    'transaction_type': 'vnpay_topup',
    'status': 'completed',
    'amount': amount,
    'available_delta': amount,
    'held_delta': 0,
    'created_at': createdAt,
  });
}
