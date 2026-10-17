import 'package:giaohang_mobile/features/customer/screens/create_order/controllers/order_finance_form_controller.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/create_order_payment_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_mobile/core/models/customer_wallet.dart';
import 'package:giaohang_mobile/core/providers/customer_wallet_providers.dart';

void main() {
  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('payment choices preserve COD and update totals at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = OrderFinanceFormController();
      final key = GlobalKey<FormState>();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerWalletSummaryProvider.overrideWith(
              (_) async => const CustomerWalletSummary(
                availableBalance: 100000,
                totalReceived: 100000,
              ),
            ),
            customerWalletChangesProvider.overrideWith(
              (_) => const Stream<int>.empty(),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.6),
              ),
              child: Scaffold(
                body: CreateOrderPaymentBody(
                  formKey: key,
                  controller: controller,
                  deliveryFee: 25000,
                ),
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '120000');
      await tester.pump();
      expect(key.currentState!.validate(), isTrue);
      await tester.scrollUntilVisible(
        find.text('145.000đ'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('145.000đ'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Tiền hàng đã thanh toán'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Tiền hàng đã thanh toán'));
      await tester.pump();
      expect(controller.codCollectionAmount, 0);
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(find.byType(TextFormField), '50000');
      expect(key.currentState!.validate(), isTrue);
      expect(controller.goodsValue, 50000);
      expect(find.text('145.000đ'), findsNothing);
      expect(find.text('0đ'), findsOneWidget);
      expect(controller.financeFor(25000).receiverCollectionAmount, 0);
      expect(controller.financeFor(25000).senderVnpayAmount, 25000);
      expect(find.text('Trả phí giao bằng ví của bạn'), findsOneWidget);
      expect(find.text('Trừ từ ví của bạn'), findsOneWidget);
      expect(find.text('75.000đ'), findsOneWidget);
      await tester.tap(find.text('Thanh toán khi nhận hàng'));
      await tester.pump();
      expect(controller.codCollectionAmount, 120000);
      await tester.enterText(find.byType(TextFormField), '2500000');
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Tối đa 2.000.000đ.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
