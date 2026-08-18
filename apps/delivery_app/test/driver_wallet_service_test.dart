import 'package:delivery_app/core/services/driver_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads wallet summary and transaction history from RPCs', () async {
    final service = DriverWalletService(
      rpcInvoker: (name, params) async {
        if (name == 'get_driver_wallet_summary') {
          return [
            {
              'available_balance': 500000,
              'held_balance': 123750,
              'today_income': 21250,
            },
          ];
        }
        return [
          {
            'id': 'tx-1',
            'transaction_type': 'vnpay_topup',
            'status': 'completed',
            'amount': 500000,
            'available_delta': 500000,
            'held_delta': 0,
            'created_at': '2026-08-14T08:00:00Z',
          },
        ];
      },
      functionInvoker: (_, _) async => const {},
    );

    final summary = await service.getSummary();
    final transactions = await service.getTransactions();

    expect(summary.availableBalance, 500000);
    expect(summary.heldBalance, 123750);
    expect(summary.todayIncome, 21250);
    expect(transactions.single.signedAmount, 500000);
  });

  test('creates a VNPAY payment URL for a valid top-up', () async {
    final service = DriverWalletService(
      rpcInvoker: (_, _) async => const [],
      functionInvoker: (name, body) async {
        expect(name, 'vnpay-create-wallet-topup');
        expect(body, {'amount': 200000});
        return {'payment_url': 'https://sandbox.vnpayment.vn/pay'};
      },
    );

    final url = await service.createTopupPaymentUrl(200000);

    expect(url.host, 'sandbox.vnpayment.vn');
  });

  test('rejects top-up below VNPAY minimum before network call', () async {
    var called = false;
    final service = DriverWalletService(
      rpcInvoker: (_, _) async => const [],
      functionInvoker: (_, _) async {
        called = true;
        return const {};
      },
    );

    await expectLater(
      service.createTopupPaymentUrl(4999),
      throwsA(isA<DriverWalletException>()),
    );
    expect(called, isFalse);
  });

  test('emits a new revision for each realtime wallet snapshot', () async {
    final service = DriverWalletService(
      rpcInvoker: (_, _) async => const [],
      functionInvoker: (_, _) async => const {},
      changeWatcher: () => Stream.fromIterable([
        const [],
        const [{}],
      ]),
    );

    expect(await service.watchChanges().toList(), [1, 2]);
  });
}
