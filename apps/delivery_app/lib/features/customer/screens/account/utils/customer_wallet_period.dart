import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/customer_wallet.dart';

enum CustomerWalletPeriod { day, week, month }

class CustomerWalletPeriodSelection {
  const CustomerWalletPeriodSelection({
    required this.period,
    required this.anchorDate,
  });

  final CustomerWalletPeriod period;
  final DateTime anchorDate;

  DateTime get start {
    final day = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    return switch (period) {
      CustomerWalletPeriod.day => day,
      CustomerWalletPeriod.week => day.subtract(
        Duration(days: day.weekday - DateTime.monday),
      ),
      CustomerWalletPeriod.month => DateTime(day.year, day.month),
    };
  }

  DateTime get endExclusive => switch (period) {
    CustomerWalletPeriod.day => start.add(const Duration(days: 1)),
    CustomerWalletPeriod.week => start.add(const Duration(days: 7)),
    CustomerWalletPeriod.month => DateTime(start.year, start.month + 1),
  };

  List<CustomerWalletTransaction> filter(
    Iterable<CustomerWalletTransaction> transactions,
  ) {
    return transactions.where((transaction) {
        final date = VietnamTime.toWallClock(transaction.createdAt);
        return !date.isBefore(start) && date.isBefore(endExclusive);
      }).toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  int received(Iterable<CustomerWalletTransaction> transactions) => transactions
      .where((transaction) => transaction.availableDelta > 0)
      .fold(0, (total, transaction) => total + transaction.availableDelta);

  int spent(Iterable<CustomerWalletTransaction> transactions) => transactions
      .where((transaction) => transaction.availableDelta < 0)
      .fold(
        0,
        (total, transaction) => total + transaction.availableDelta.abs(),
      );

  CustomerWalletPeriodSelection shift(int amount) {
    final nextAnchor = switch (period) {
      CustomerWalletPeriod.day => anchorDate.add(Duration(days: amount)),
      CustomerWalletPeriod.week => anchorDate.add(Duration(days: amount * 7)),
      CustomerWalletPeriod.month => DateTime(
        anchorDate.year,
        anchorDate.month + amount,
        1,
      ),
    };
    return CustomerWalletPeriodSelection(
      period: period,
      anchorDate: nextAnchor,
    );
  }

  CustomerWalletPeriodSelection withPeriod(CustomerWalletPeriod value) =>
      CustomerWalletPeriodSelection(period: value, anchorDate: anchorDate);
}
