import 'dart:async';

import 'package:delivery_app/core/models/driver_wallet.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/driver_wallet_providers.dart';
import 'package:delivery_app/core/services/driver_wallet_service.dart';
import 'package:delivery_app/features/customer/screens/create_order/controllers/order_finance_form_controller.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/create_order_payment_body.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_finance_panel.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_delivery_success_dialog.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_wallet_debit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'paid goods value is separate from COD and keeps VNPAY fee unchanged',
    () {
      final controller = OrderFinanceFormController();
      addTearDown(controller.dispose);
      controller.setCodCollectionAmount(350000);
      controller.setCollectCod(false);
      expect(controller.goodsValue, 0);
      controller.setGoodsValue(120000);
      final finance = controller.financeFor(25000);
      expect(finance.goodsValue, 120000);
      expect(finance.driverAdvanceAmount, 120000);
      expect(finance.receiverCollectionAmount, 0);
      expect(finance.senderVnpayAmount, 25000);
      expect(finance.totalPrice, 25000);
      controller.setCollectCod(true);
      expect(controller.codCollectionAmount, 350000);
      expect(controller.goodsValue, 0);
      controller.setCollectCod(false);
      expect(controller.goodsValue, 120000);
    },
  );

  test('legacy prepaid and sender-paid COD do not opt into deposits', () {
    expect(_order(advance: 0).requiresPaidGoodsDeposit, isFalse);
    expect(_order().requiresPaidGoodsDeposit, isTrue);
    expect(
      _order().copyWith(codCollectionAmount: 120000).requiresPaidGoodsDeposit,
      isFalse,
    );
  });

  testWidgets('paid goods value is required and capped without copying COD', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = OrderFinanceFormController();
    addTearDown(controller.dispose);
    controller.setCodCollectionAmount(350000);
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateOrderPaymentBody(
            formKey: key,
            controller: controller,
            deliveryFee: 25000,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Đã thanh toán'));
    await tester.pump();
    expect(controller.goodsValueController.text, isEmpty);
    expect(find.text('Giá trị hàng *'), findsOneWidget);
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Nhập giá trị hàng để giữ tiền làm tin.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '2000001');
    expect(key.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '120000');
    expect(key.currentState!.validate(), isTrue);
    expect(controller.financeFor(25000).receiverCollectionAmount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'order card refreshes hold and refund from full per-order ledger',
    (tester) async {
      final changes = StreamController<Object?>.broadcast();
      addTearDown(changes.close);
      final receipts = <Map<String, dynamic>>[];
      var historyCalled = false;
      final service = DriverWalletService(
        rpcInvoker: (_, _) async {
          historyCalled = true;
          return const [];
        },
        functionInvoker: (_, _) async => const {},
        changeWatcher: () => changes.stream,
        orderTransactionsLoader: (orderId, driverId) async {
          expect(orderId, 'paid-order');
          expect(driverId, 'driver-1');
          return List<Map<String, dynamic>>.of(receipts);
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [driverWalletServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            home: Scaffold(
              body: DriverOrderFinancePanel(
                order: _order(status: 'delivering'),
                availableBalance: 380000,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa giữ tiền'), findsOneWidget);
      receipts.add(_receipt('cod_hold'));
      changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Đang giữ tiền làm tin'), findsOneWidget);
      receipts.add(_receipt('cod_release'));
      changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Đã hoàn tiền cọc giữ hàng'), findsOneWidget);
      expect(find.text('25.000đ'), findsOneWidget);
      expect(historyCalled, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ledger loading and failure never imply a refund, retry reloads',
    (tester) async {
      final pending = Completer<dynamic>();
      var count = 0;
      final service = DriverWalletService(
        rpcInvoker: (_, _) async => const [],
        functionInvoker: (_, _) async => const {},
        changeWatcher: () => const Stream.empty(),
        orderTransactionsLoader: (_, _) {
          count++;
          return count == 1
              ? pending.future
              : Future.value([_receipt('cod_hold'), _receipt('cod_release')]);
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [driverWalletServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            home: Scaffold(
              body: DriverOrderFinancePanel(
                order: _order(status: 'delivered'),
                availableBalance: 525000,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Đang cập nhật tiền làm tin'), findsOneWidget);
      expect(find.text('Đã hoàn tiền cọc giữ hàng'), findsNothing);
      pending.completeError(const DriverWalletException('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa xác minh tiền làm tin'), findsOneWidget);
      expect(find.text('Đã hoàn tiền cọc giữ hàng'), findsNothing);
      await tester.tap(find.byTooltip('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Đã hoàn tiền cọc giữ hàng'), findsOneWidget);
      expect(count, 2);
    },
  );

  testWidgets('completion dialog cannot announce a refund without receipts', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showDriverDeliverySuccessDialog(context, expectsGoodsDeposit: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa xác minh tiền làm tin'), findsOneWidget);
    expect(find.text('Đã hoàn tiền cọc giữ hàng'), findsNothing);
    await tester.tap(find.text('Hoàn tất'));
    await tester.pumpAndSettle();
  });

  testWidgets('hold confirmation fits short screen with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    unawaited(
      showDriverWalletDebitDialog(
        context: context,
        debitedAmount: 120000,
        availableBalance: 380000,
        isGoodsDeposit: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ĐÃ GIỮ TIỀN LÀM TIN'), findsOneWidget);
    await tester.ensureVisible(find.text('Tiếp tục giao hàng'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tiếp tục giao hàng'));
    await tester.pumpAndSettle();
  });
}

OrderModel _order({String status = 'picking_up', int advance = 120000}) =>
    OrderModel.fromJson({
      'id': 'paid-order',
      'customer_id': 'customer-1',
      'driver_id': 'driver-1',
      'status': status,
      'pickup_address': 'A',
      'delivery_address': 'B',
      'delivery_fee_payer': 'sender',
      'payment_status': 'paid',
      'payment_mode': 'prepaid',
      'goods_value': 120000,
      'cod_collection_amount': 0,
      'driver_advance_amount': advance,
      'driver_net_earning': 25000,
      'receiver_collection_amount': 0,
    });

Map<String, dynamic> _receipt(String type) => {
  'id': type,
  'order_id': 'paid-order',
  'driver_id': 'driver-1',
  'transaction_type': type,
  'status': 'completed',
  'amount': 120000,
  'available_delta': type == 'cod_hold' ? -120000 : 120000,
  'held_delta': type == 'cod_hold' ? 120000 : -120000,
  'metadata': {'purpose': DriverWalletTransaction.paidGoodsDepositPurpose},
};
