import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/models/order_finance.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/order_submission_payload.dart';
import 'package:giaohang_mobile/core/utils/delivery_eta_calculator.dart';
import 'package:giaohang_mobile/core/utils/platform_fee_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/order_form_data.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/order_form_submission.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_finance_summary.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_incoming_offer_finance.dart';
import 'helpers/customer_account_fixtures.dart';

OrderFormData _form() => OrderFormData(
  pickupAddress: 'Điểm lấy',
  pickupLat: 10.77,
  pickupLng: 106.67,
  deliveryAddress: 'Điểm giao',
  deliveryLat: 10.79,
  deliveryLng: 106.69,
  senderName: 'Người gửi',
  senderPhone: '0900000000',
  recipientName: 'Người nhận',
  recipientPhone: '0900000001',
  note: '',
  itemName: 'Kiện hàng',
  itemCategory: 'document',
  itemDescription: '',
  cargoImage: null,
  paymentMethod: 'cash',
  deliveryFeePayer: DeliveryFeePayer.recipient,
  goodsValue: 0,
  codCollectionAmount: 120000,
  deliveryFee: 25000,
  totalPrice: 146250,
  distanceMeters: 3000,
  feeBreakdown: DeliveryPricingPolicy.calculate(distanceMeters: 3000),
  deliveryEta: DeliveryEtaCalculator.calculate(distanceMeters: 3000),
  customerPlatformFeeRateBps: 500,
  driverPlatformFeeRateBps: 1000,
  settingsRevision: 6,
);

void main() {
  setUpAll(() async {
    await loadCustomerAccountTestFonts();
    final icons = File.fromUri(
      File(
        Platform.resolvedExecutable,
      ).parent.uri.resolve('../../material_fonts/materialicons-regular.otf'),
    );
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  });
  test(
    'customer and driver fees affect their own money without changing COD',
    () {
      for (final payer in DeliveryFeePayer.values) {
        final finance = OrderFinance.calculate(
          deliveryFeePayer: payer,
          deliveryFee: 25000,
          goodsValue: 120000,
          codCollectionAmount: 120000,
          customerPlatformFeeAmount: 1250,
          driverPlatformFeeAmount: 2500,
        );
        expect(finance.driverNetEarning, 22500);
        expect(finance.driverAdvanceAmount, 120000);
        expect(finance.totalPrice, 146250);
        expect(finance.customerServiceCharge, 26250);
        expect(
          finance.receiverCollectionAmount,
          payer == DeliveryFeePayer.recipient ? 146250 : 120000,
        );
        expect(
          finance.senderVnpayAmount,
          payer == DeliveryFeePayer.sender ? 26250 : 0,
        );
      }
    },
  );
  test('rounding matches PostgreSQL for zero, fractional and full rates', () {
    expect(BusinessSettings.calculatePlatformFee(18001, 0), 0);
    expect(BusinessSettings.calculatePlatformFee(18001, 1), 2);
    expect(BusinessSettings.calculatePlatformFee(18001, 10000), 18001);
    expect(BusinessSettings.calculatePlatformFee(18050, 100), 181);
  });
  test('form, payload and persisted model retain the fee snapshot', () {
    final order = buildOrderFromForm(
      data: _form(),
      customerId: 'customer',
      now: DateTime.utc(2026),
    );
    expect(order.customerPlatformFeeAmount, 1250);
    expect(order.platformFeeAmount, 2500);
    expect(order.netDriverIncome, 22500);
    expect(order.totalPrice, 146250);
    expect(order.receiverCollectionAmount, 146250);
    final payload = buildOrderSubmissionPayload(order);
    expect(payload['quoted_customer_fee'], 1250);
    expect(payload, isNot(contains('platform_fee_amount')));
    final loaded = OrderModel.fromJson(
      order.copyWith(customerPlatformFeeAmount: 1300).toJson(),
    );
    expect(loaded.customerPlatformFeeAmount, 1300);
    expect(
      loaded.copyWith(status: 'confirmed').customerPlatformFeeRateBps,
      500,
    );
    final zero = loaded.copyWith(
      platformFeeRateBps: 10000,
      driverNetEarning: 0,
    );
    expect(zero.netDriverIncome, 0);
  });
  for (final scale in [1.0, 1.6]) {
    testWidgets(
      'customer total and driver fee/net remain readable at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final order = buildOrderFromForm(
          data: _form(),
          customerId: 'customer',
          now: DateTime.utc(2026),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: AppTextStyles.bodyMedium.fontFamily),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(375, 667),
                textScaler: TextScaler.linear(scale),
              ),
              child: RepaintBoundary(
                key: key,
                child: Scaffold(
                  backgroundColor: AppColors.bgLight,
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        OrderFinanceSummary(data: _form()),
                        const SizedBox(height: AppSpacing.lg),
                        DriverIncomingOfferFinance(order: order),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('146.250đ'), findsOneWidget);
        expect(find.text('1.250đ'), findsOneWidget);
        expect(find.text('2.500đ'), findsOneWidget);
        expect(find.text('22.500đ'), findsOneWidget);
        expect(find.text(PlatformFeeText.netIncome), findsOneWidget);
        expect(tester.takeException(), isNull);
        final path = Platform.environment['GIAOHANG_FEE_CAPTURE'];
        if (scale == 1 && path != null) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(path).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
