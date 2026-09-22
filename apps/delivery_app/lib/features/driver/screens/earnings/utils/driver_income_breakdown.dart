import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/driver_wallet.dart';
import 'driver_wallet_period.dart';

class DriverIncomeBucket {
  const DriverIncomeBucket({required this.label, required this.amount});

  final String label;
  final int amount;
}

List<DriverIncomeBucket> buildDriverIncomeBreakdown({
  required DriverWalletPeriodSelection selection,
  required Iterable<DriverWalletTransaction> transactions,
}) {
  final income = selection
      .filter(transactions)
      .where((transaction) => transaction.isIncome)
      .toList();

  return switch (selection.period) {
    DriverWalletPeriod.day => _dayBuckets(income),
    DriverWalletPeriod.week => _weekBuckets(selection, income),
    DriverWalletPeriod.month => _monthBuckets(selection, income),
  };
}

List<DriverIncomeBucket> _dayBuckets(
  List<DriverWalletTransaction> transactions,
) {
  return List.generate(6, (index) {
    final startHour = index * 4;
    final amount = transactions
        .where((transaction) {
          final hour = VietnamTime.toWallClock(transaction.createdAt).hour;
          return hour >= startHour && hour < startHour + 4;
        })
        .fold(0, (total, transaction) => total + transaction.amount);
    return DriverIncomeBucket(
      label: '${startHour.toString().padLeft(2, '0')}h',
      amount: amount,
    );
  });
}

List<DriverIncomeBucket> _weekBuckets(
  DriverWalletPeriodSelection selection,
  List<DriverWalletTransaction> transactions,
) {
  const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  return List.generate(7, (index) {
    final date = selection.start.add(Duration(days: index));
    final amount = transactions
        .where((transaction) {
          final local = VietnamTime.toWallClock(transaction.createdAt);
          return local.year == date.year &&
              local.month == date.month &&
              local.day == date.day;
        })
        .fold(0, (total, transaction) => total + transaction.amount);
    return DriverIncomeBucket(label: labels[index], amount: amount);
  });
}

List<DriverIncomeBucket> _monthBuckets(
  DriverWalletPeriodSelection selection,
  List<DriverWalletTransaction> transactions,
) {
  final lastDay = selection.endExclusive.subtract(const Duration(days: 1)).day;
  final buckets = <DriverIncomeBucket>[];
  for (var startDay = 1; startDay <= lastDay; startDay += 7) {
    final endDay = (startDay + 6).clamp(1, lastDay);
    final amount = transactions
        .where((transaction) {
          final local = VietnamTime.toWallClock(transaction.createdAt);
          return local.day >= startDay && local.day <= endDay;
        })
        .fold(0, (total, transaction) => total + transaction.amount);
    buckets.add(
      DriverIncomeBucket(
        label:
            '${startDay.toString().padLeft(2, '0')}–'
            '${endDay.toString().padLeft(2, '0')}',
        amount: amount,
      ),
    );
  }
  return buckets;
}
