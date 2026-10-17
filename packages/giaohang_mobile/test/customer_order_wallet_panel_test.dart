import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:giaohang_mobile/core/models/customer_wallet.dart';
import 'package:giaohang_mobile/core/providers/customer_wallet_providers.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/controllers/order_finance_form_controller.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/create_order_payment_body.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_confirmation_wallet_card.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_confirmation_submit_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/utraffic_capture_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('CAPTURE_WALLET_PREVIEW')) {
    setUpAll(prepareUtrafficCaptureFonts);
  }
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1200, 800),
  ]) {
    testWidgets('prepaid wallet amounts fit $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = OrderFinanceFormController()
        ..setCollectCod(false)
        ..setGoodsValue(50000);
      addTearDown(controller.dispose);
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        _scope(
          balance: 100000,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.6),
              ),
              child: RepaintBoundary(
                key: previewKey,
                child: Scaffold(
                  appBar: AppBar(title: const Text('Tạo đơn mới')),
                  body: CreateOrderPaymentBody(
                    formKey: GlobalKey<FormState>(),
                    controller: controller,
                    deliveryFee: 18000,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100.000đ'), findsOneWidget);
      expect(find.text('82.000đ'), findsOneWidget);
      expect(find.text('0đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_WALLET_PREVIEW') &&
          size.width == 390) {
        final boundary =
            previewKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('.tmp')..createSync(recursive: true);
          await File(
            '${directory.path}/wallet_payment_preview.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets(
    'insufficient wallet shows shortfall and an explicit VNPAY choice',
    (tester) async {
      var switches = 0;
      await tester.pumpWidget(
        _scope(
          balance: 10000,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OrderConfirmationWalletCard(
                  deliveryFee: 18000,
                  useVnpay: false,
                  canSwitch: true,
                  onVnpaySelected: () => switches++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ví không đủ tiền trả phí giao.'), findsOneWidget);
      expect(find.text('Số dư sau khi đặt'), findsNothing);
      await tester.tap(find.text('Chọn thanh toán qua VNPAY'));
      expect(switches, 1);
    },
  );

  testWidgets('pending wallet result hides payment switching', (tester) async {
    await tester.pumpWidget(
      _scope(
        balance: 100000,
        child: MaterialApp(
          home: Scaffold(
            body: OrderConfirmationWalletCard(
              deliveryFee: 18000,
              useVnpay: false,
              canSwitch: false,
              onVnpaySelected: () => fail('Must not switch'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chọn thanh toán qua VNPAY'), findsNothing);
  });

  testWidgets('confirmation cannot submit while wallet is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OrderConfirmationSubmitBar(
            isSubmitting: false,
            isEnabled: false,
            idleLabel: 'Trả bằng ví và đặt đơn',
            onSubmit: () => fail('Insufficient wallet'),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
  });
}

Widget _scope({required int balance, required Widget child}) => ProviderScope(
  overrides: [
    customerWalletSummaryProvider.overrideWith(
      (_) async => CustomerWalletSummary(
        availableBalance: balance,
        totalReceived: 100000,
      ),
    ),
    customerWalletChangesProvider.overrideWith(
      (_) => const Stream<int>.empty(),
    ),
  ],
  child: child,
);
