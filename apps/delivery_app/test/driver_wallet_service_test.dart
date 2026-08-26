import 'dart:async';

import 'package:delivery_app/core/models/driver_wallet.dart';
import 'package:delivery_app/core/providers/driver_wallet_providers.dart';
import 'package:delivery_app/core/services/driver_wallet_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  test('reloads the cached wallet summary after a realtime top-up', () async {
    final changes = StreamController<Object?>.broadcast();
    var availableBalance = 0;
    final service = DriverWalletService(
      rpcInvoker: (_, _) async => [
        {
          'available_balance': availableBalance,
          'held_balance': 0,
          'today_income': 0,
        },
      ],
      functionInvoker: (_, _) async => const {},
      changeWatcher: () => changes.stream,
    );
    final container = ProviderContainer(
      overrides: [driverWalletServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() async {
      container.dispose();
      await changes.close();
    });
    final subscription = container.listen(
      driverWalletSummaryProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      (await container.read(
        driverWalletSummaryProvider.future,
      )).availableBalance,
      0,
    );

    availableBalance = 250000;
    changes.add(const <Object?>[]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      (await container.read(
        driverWalletSummaryProvider.future,
      )).availableBalance,
      250000,
    );
  });

  test('reloads cached wallet transactions after a realtime top-up', () async {
    final changes = StreamController<Object?>.broadcast();
    var transactionAmount = 0;
    final service = DriverWalletService(
      rpcInvoker: (name, _) async {
        if (name != 'get_driver_wallet_transactions') return const [];
        return [
          {
            'id': 'tx-1',
            'transaction_type': 'vnpay_topup',
            'status': 'completed',
            'amount': transactionAmount,
            'available_delta': transactionAmount,
            'held_delta': 0,
            'created_at': '2026-08-24T02:00:00Z',
          },
        ];
      },
      functionInvoker: (_, _) async => const {},
      changeWatcher: () => changes.stream,
    );
    final container = ProviderContainer(
      overrides: [driverWalletServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() async {
      container.dispose();
      await changes.close();
    });
    final subscription = container.listen(
      driverWalletTransactionsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      (await container.read(
        driverWalletTransactionsProvider.future,
      )).single.amount,
      0,
    );

    transactionAmount = 250000;
    changes.add(const <Object?>[]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      (await container.read(
        driverWalletTransactionsProvider.future,
      )).single.amount,
      250000,
    );
  });

  test('pickup debit is visible once while legacy capture stays hidden', () {
    final pickupDebit = DriverWalletTransaction.fromJson({
      'id': 'pickup-debit',
      'transaction_type': 'cod_advance_capture',
      'status': 'completed',
      'amount': 500000,
      'available_delta': -500000,
      'held_delta': 0,
      'created_at': '2026-08-19T03:30:00Z',
    });
    final legacyCapture = DriverWalletTransaction.fromJson({
      'id': 'legacy-capture',
      'transaction_type': 'cod_advance_capture',
      'status': 'completed',
      'amount': 500000,
      'available_delta': 0,
      'held_delta': -500000,
      'created_at': '2026-08-18T03:30:00Z',
    });

    expect(pickupDebit.signedAmount, -500000);
    expect(pickupDebit.isVisibleInHistory, isTrue);
    expect(legacyCapture.signedAmount, 0);
    expect(legacyCapture.isVisibleInHistory, isFalse);
  });
}
