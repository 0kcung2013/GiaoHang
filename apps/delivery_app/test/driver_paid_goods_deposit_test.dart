import 'package:delivery_app/core/models/driver_wallet.dart';
import 'package:delivery_app/features/driver/finance/models/driver_goods_deposit.dart';
import 'package:delivery_app/features/driver/finance/widgets/driver_goods_deposit_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows amount required before any hold receipt exists', () {
    expect(_snapshot([]).status, DriverGoodsDepositStatus.required);
  });

  test('valid hold moves principal into held balance', () {
    final hold = _hold();
    expect(_snapshot([hold]).status, DriverGoodsDepositStatus.held);
    expect(hold.signedAmount, -120000);
    expect(hold.label, 'Giữ tiền làm tin');
    expect(hold.isIncome, isFalse);
  });

  test('completed order alone never claims the deposit was refunded', () {
    expect(
      _snapshot([_hold()], completed: true).status,
      DriverGoodsDepositStatus.refundPending,
    );
    expect(
      _snapshot([], completed: true).status,
      DriverGoodsDepositStatus.verificationRequired,
    );
  });

  test('confirmed full release is a refund and is not delivery income', () {
    final release = _release();
    final earning = _transaction(
      id: 'income',
      type: 'prepaid_earning',
      amount: 25000,
      available: 25000,
      held: 0,
      purpose: null,
    );
    expect(
      _snapshot([_hold(), release, earning], completed: true).status,
      DriverGoodsDepositStatus.refunded,
    );
    expect(release.label, 'Hoàn tiền làm tin');
    expect(release.signedAmount, 120000);
    expect(release.isIncome, isFalse);
    expect(earning.isIncome, isTrue);
    expect(
      [_hold(), release, earning]
          .where((tx) => tx.isIncome)
          .fold<int>(0, (total, tx) => total + tx.amount),
      25000,
    );
  });

  test(
    'refund receipts from another order or driver do not release this hold',
    () {
      expect(
        _snapshot([
          _hold(),
          _release(orderId: 'other-order'),
          _release(driverId: 'other-driver'),
        ], completed: true).status,
        DriverGoodsDepositStatus.refundPending,
      );
    },
  );

  test('failed and pending receipts do not change completed wallet state', () {
    expect(
      _snapshot([_hold(status: 'pending')]).status,
      DriverGoodsDepositStatus.required,
    );
    expect(
      _snapshot([_hold(), _release(status: 'failed')], completed: true).status,
      DriverGoodsDepositStatus.refundPending,
    );
  });

  test('legacy COD holds and refunds retain their labels and are excluded', () {
    final hold = _hold(purpose: null);
    final release = _release(purpose: null);
    expect(hold.label, 'Ứng tiền hàng');
    expect(release.label, 'Hoàn tiền ứng COD');
    expect(
      _snapshot([hold, release]).status,
      DriverGoodsDepositStatus.required,
    );
  });

  test('duplicate snapshots of the same receipt are counted once', () {
    final hold = _hold();
    final release = _release();
    expect(
      _snapshot([hold, release, hold, release]).status,
      DriverGoodsDepositStatus.refunded,
    );
  });

  test('partial or inconsistent refund needs reconciliation', () {
    for (final transactions in [
      [_hold(), _release(amount: 100000)],
      [_release()],
      [_hold(), _release(held: 0)],
      [_hold(), _release(amount: 130000)],
      [_hold(), _hold(id: 'double-hold')],
      [_hold(id: '')],
      [
        _hold(),
        _transaction(
          id: 'unexpected-capture',
          type: 'cod_advance_capture',
          amount: 120000,
          available: 0,
          held: -120000,
        ),
      ],
    ]) {
      expect(
        _snapshot(transactions, completed: true).status,
        DriverGoodsDepositStatus.verificationRequired,
      );
    }
  });

  test('zero goods value cannot fabricate a deposit', () {
    expect(
      () => DriverGoodsDeposit.fromTransactions(
        orderId: 'order-1',
        driverId: 'driver-1',
        expectedAmount: 0,
        deliveryCompleted: false,
        transactions: const [],
      ),
      throwsArgumentError,
    );
  });

  testWidgets('UI updates held to refunded and keeps earning separate', (
    tester,
  ) async {
    Future<void> show(DriverGoodsDeposit deposit) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverGoodsDepositPanel(
            deposit: deposit,
            receiverCollectionAmount: 0,
            driverNetEarning: 25000,
            availableBalance: 0,
          ),
        ),
      ),
    );
    await show(_snapshot([_hold()]));
    expect(find.text('Đang giữ tiền làm tin'), findsOneWidget);
    expect(find.text('0đ'), findsOneWidget);
    expect(find.text('25.000đ'), findsOneWidget);
    expect(find.textContaining('Nạp thêm'), findsNothing);
    await show(_snapshot([_hold(), _release()], completed: true));
    expect(find.text('Đã hoàn tiền cọc giữ hàng'), findsOneWidget);
    expect(find.text('+120.000đ'), findsOneWidget);
    expect(find.text('Thu nhập giao hàng'), findsOneWidget);
    expect(find.text('25.000đ'), findsOneWidget);
    expect(find.text('145.000đ'), findsNothing);
  });

  testWidgets('completed order without release stays pending on screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverGoodsDepositPanel(
            deposit: _snapshot([_hold()], completed: true),
            receiverCollectionAmount: 0,
            driverNetEarning: 25000,
          ),
        ),
      ),
    );
    expect(find.text('Chờ xác nhận hoàn tiền'), findsOneWidget);
    expect(find.text('Đã hoàn tiền cọc giữ hàng'), findsNothing);
    expect(find.text('+120.000đ'), findsNothing);
  });

  testWidgets(
    'small viewport with large text and wide viewport remain usable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [const Size(320, 568), const Size(1024, 768)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: DriverGoodsDepositPanel(
                        deposit: _snapshot([]),
                        receiverCollectionAmount: 0,
                        driverNetEarning: 25000,
                        availableBalance: 50000,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.text('Nạp thêm 70.000đ'));
        expect(find.text('Chưa giữ tiền'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

DriverGoodsDeposit _snapshot(
  List<DriverWalletTransaction> transactions, {
  bool completed = false,
}) => DriverGoodsDeposit.fromTransactions(
  orderId: 'order-1',
  driverId: 'driver-1',
  expectedAmount: 120000,
  deliveryCompleted: completed,
  transactions: transactions,
);

DriverWalletTransaction _hold({
  String id = 'hold',
  String status = 'completed',
  String? purpose = DriverGoodsDeposit.purpose,
}) => _transaction(
  id: id,
  type: 'cod_hold',
  amount: 120000,
  available: -120000,
  held: 120000,
  status: status,
  purpose: purpose,
);

DriverWalletTransaction _release({
  String orderId = 'order-1',
  String driverId = 'driver-1',
  String status = 'completed',
  int amount = 120000,
  int? held,
  String? purpose = DriverGoodsDeposit.purpose,
}) => _transaction(
  id: 'release-$orderId-$driverId',
  type: 'cod_release',
  amount: amount,
  available: amount,
  held: held ?? -amount,
  orderId: orderId,
  driverId: driverId,
  status: status,
  purpose: purpose,
);

DriverWalletTransaction _transaction({
  required String id,
  required String type,
  required int amount,
  required int available,
  required int held,
  String orderId = 'order-1',
  String driverId = 'driver-1',
  String status = 'completed',
  String? purpose = DriverGoodsDeposit.purpose,
}) => DriverWalletTransaction.fromJson({
  'id': id,
  'order_id': orderId,
  'driver_id': driverId,
  'transaction_type': type,
  'status': status,
  'amount': amount,
  'available_delta': available,
  'held_delta': held,
  'created_at': '2026-10-08T08:00:00Z',
  'metadata': {'purpose': ?purpose},
});
