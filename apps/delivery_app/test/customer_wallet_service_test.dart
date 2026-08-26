import 'package:delivery_app/core/services/customer_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads customer balance and COD settlement history', () async {
    final service = CustomerWalletService(
      rpcInvoker: (name, params) async {
        if (name == 'get_customer_wallet_summary') {
          return [
            {'available_balance': 500000, 'total_received': 800000},
          ];
        }
        expect(name, 'get_customer_wallet_transactions');
        expect(params, {'p_limit': 10});
        return [
          {
            'id': 'customer-tx-1',
            'transaction_type': 'delivery_credit',
            'amount': 500000,
            'available_delta': 500000,
            'created_at': '2026-08-19T03:30:00Z',
          },
        ];
      },
      changeWatcher: () => const Stream.empty(),
    );

    final summary = await service.getSummary();
    final transactions = await service.getTransactions();

    expect(summary.availableBalance, 500000);
    expect(summary.totalReceived, 800000);
    expect(transactions.single.label, 'Tiền hàng giao thành công');
    expect(transactions.single.availableDelta, 500000);
  });

  test('emits revisions for realtime customer wallet snapshots', () async {
    final service = CustomerWalletService(
      rpcInvoker: (_, _) async => const [],
      changeWatcher: () => Stream.fromIterable([
        const [],
        const [{}],
      ]),
    );

    expect(await service.watchChanges().toList(), [1, 2]);
  });
}
