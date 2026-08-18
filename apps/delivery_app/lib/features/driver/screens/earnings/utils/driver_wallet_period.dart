import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/driver_wallet.dart';

enum DriverWalletPeriod { day, week, month }

class DriverWalletPeriodSelection {
  const DriverWalletPeriodSelection({
    required this.period,
    required this.anchorDate,
  });

  final DriverWalletPeriod period;
  final DateTime anchorDate;

  DateTime get start {
    final day = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    return switch (period) {
      DriverWalletPeriod.day => day,
      DriverWalletPeriod.week => day.subtract(
        Duration(days: day.weekday - DateTime.monday),
      ),
      DriverWalletPeriod.month => DateTime(day.year, day.month),
    };
  }

  DateTime get endExclusive => switch (period) {
    DriverWalletPeriod.day => start.add(const Duration(days: 1)),
    DriverWalletPeriod.week => start.add(const Duration(days: 7)),
    DriverWalletPeriod.month => DateTime(start.year, start.month + 1),
  };

  List<DriverWalletTransaction> filter(
    Iterable<DriverWalletTransaction> transactions,
  ) {
    return transactions.where((transaction) {
        final date = VietnamTime.toWallClock(transaction.createdAt);
        return !date.isBefore(start) && date.isBefore(endExclusive);
      }).toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  int income(Iterable<DriverWalletTransaction> transactions) => transactions
      .where((transaction) => transaction.isIncome)
      .fold(0, (total, transaction) => total + transaction.amount);

  DriverWalletPeriodSelection shift(int amount) {
    final nextAnchor = switch (period) {
      DriverWalletPeriod.day => anchorDate.add(Duration(days: amount)),
      DriverWalletPeriod.week => anchorDate.add(Duration(days: amount * 7)),
      DriverWalletPeriod.month => DateTime(
        anchorDate.year,
        anchorDate.month + amount,
        1,
      ),
    };
    return DriverWalletPeriodSelection(period: period, anchorDate: nextAnchor);
  }

  DriverWalletPeriodSelection withPeriod(DriverWalletPeriod value) =>
      DriverWalletPeriodSelection(period: value, anchorDate: anchorDate);
}
