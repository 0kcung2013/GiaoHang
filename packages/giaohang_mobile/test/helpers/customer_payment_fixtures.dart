import 'package:giaohang_mobile/features/customer/screens/payments/data/customer_payment_repository.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/models/customer_payment.dart';

CustomerPayment paymentFixture({
  String id = 'payment-1',
  CustomerPaymentMethod method = CustomerPaymentMethod.wallet,
  CustomerPaymentState state = CustomerPaymentState.completed,
  int amount = 35000,
  DateTime? date,
}) => CustomerPayment(
  id: id,
  method: method,
  state: state,
  amount: amount,
  createdAt: date ?? DateTime.utc(2026, 10, 27, 7, 30),
  trackingCode: 'GH261027001',
  providerReference: method == CustomerPaymentMethod.vnpay ? 'VNP$id' : null,
  orderId: 'order-1',
);

List<CustomerPayment> paymentFixtures() => [
  paymentFixture(
    id: 'wallet-held',
    state: CustomerPaymentState.reserved,
    amount: 28000,
  ),
  paymentFixture(
    id: 'vnpay-paid',
    method: CustomerPaymentMethod.vnpay,
    amount: 62000,
  ),
  paymentFixture(
    id: 'wallet-paid',
    amount: 38000,
    date: DateTime.utc(2026, 10, 24, 4),
  ),
  paymentFixture(
    id: 'refund',
    state: CustomerPaymentState.refunded,
    amount: 25000,
    date: DateTime.utc(2026, 10, 22, 7),
  ),
  paymentFixture(
    id: 'refund-pending',
    method: CustomerPaymentMethod.vnpay,
    state: CustomerPaymentState.refundPending,
    amount: 46000,
    date: DateTime.utc(2026, 10, 21, 7),
  ),
  paymentFixture(
    id: 'old-vnpay',
    method: CustomerPaymentMethod.vnpay,
    amount: 105000,
    date: DateTime.utc(2026, 10, 13, 7),
  ),
  paymentFixture(
    id: 'old-wallet',
    amount: 75000,
    date: DateTime.utc(2026, 10, 8, 7),
  ),
];

class FakeCustomerPaymentRepository implements CustomerPaymentRepository {
  List<CustomerPayment> rows = paymentFixtures();
  bool fail = false;
  int calls = 0;
  Future<List<CustomerPayment>> Function(CustomerPaymentRange)? onFetch;
  @override
  Future<List<CustomerPayment>> fetch(CustomerPaymentRange range) async {
    calls++;
    if (onFetch != null) return onFetch!(range);
    if (fail) throw Exception('Offline');
    final start = DateTime.utc(
      range.start.year,
      range.start.month,
      range.start.day,
    ).subtract(const Duration(hours: 7));
    final end = DateTime.utc(
      range.end.year,
      range.end.month,
      range.end.day,
    ).subtract(const Duration(hours: 7));
    return rows
        .where(
          (row) =>
              !row.createdAt.isBefore(start) && row.createdAt.isBefore(end),
        )
        .toList();
  }
}
