import 'package:giaohang_domain/giaohang_domain.dart';

import '../../account/utils/customer_wallet_period.dart';
import 'customer_payment.dart';

class CustomerPaymentStatistics {
  CustomerPaymentStatistics(
    Iterable<CustomerPayment> payments, {
    CustomerPaymentMethod? method,
  }) : payments = payments
           .where((p) => method == null || p.method == method)
           .toList();
  final List<CustomerPayment> payments;
  List<CustomerPayment> get completed =>
      payments.where((p) => p.state == CustomerPaymentState.completed).toList();
  int get total => completed.fold(0, (sum, p) => sum + p.amount);
  int amount(CustomerPaymentState state) => payments
      .where((p) => p.state == state)
      .fold(0, (sum, p) => sum + p.amount);
  int methodTotal(CustomerPaymentMethod method) => completed
      .where((p) => p.method == method)
      .fold(0, (sum, p) => sum + p.amount);

  List<CustomerPaymentBucket> buckets(CustomerWalletPeriodSelection selection) {
    final day = selection.period == CustomerWalletPeriod.day;
    final week = selection.period == CustomerWalletPeriod.week;
    final count = day
        ? 4
        : week
        ? 7
        : (selection.endExclusive.difference(selection.start).inDays / 5)
              .ceil();
    return List.generate(count, (index) {
      final start = day
          ? selection.start.add(Duration(hours: index * 6))
          : selection.start.add(Duration(days: index * (week ? 1 : 5)));
      final candidate = day
          ? start.add(const Duration(hours: 6))
          : start.add(Duration(days: week ? 1 : 5));
      final end = candidate.isAfter(selection.endExclusive)
          ? selection.endExclusive
          : candidate;
      final rows = completed.where((payment) {
        final local = VietnamTime.toWallClock(payment.createdAt);
        return !local.isBefore(start) && local.isBefore(end);
      }).toList();
      final label = day
          ? '${start.hour}h'
          : week
          ? (start.weekday == 7 ? 'CN' : 'T${start.weekday + 1}')
          : start.day == end.subtract(const Duration(days: 1)).day
          ? '${start.day}'
          : '${start.day}–${end.subtract(const Duration(days: 1)).day}';
      return CustomerPaymentBucket(label: label, payments: rows);
    });
  }
}

class CustomerPaymentBucket {
  const CustomerPaymentBucket({required this.label, required this.payments});
  final String label;
  final List<CustomerPayment> payments;
  int total(CustomerPaymentMethod method) => payments
      .where((p) => p.method == method)
      .fold(0, (sum, p) => sum + p.amount);
  int get amount => payments.fold(0, (sum, p) => sum + p.amount);
}
