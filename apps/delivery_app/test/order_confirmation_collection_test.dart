import 'package:delivery_app/core/models/order_finance.dart';
import 'package:delivery_app/core/models/order_submission_payload.dart';
import 'package:delivery_app/core/utils/delivery_eta_calculator.dart';
import 'package:delivery_app/core/utils/delivery_pricing_policy.dart';
import 'package:delivery_app/features/customer/screens/create_order/controllers/order_finance_form_controller.dart';
import 'package:delivery_app/features/customer/screens/create_order/utils/order_form_data.dart';
import 'package:delivery_app/features/customer/screens/create_order/utils/order_form_submission.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/order_finance_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepaid choice submits zero collection and awaits server payment', () {
    final controller = OrderFinanceFormController();
    addTearDown(controller.dispose);
    controller.setCodCollectionAmount(120000);
    controller.setCollectCod(false);
    controller.setGoodsValue(120000);

    final order = buildOrderFromForm(
      data: _form(controller),
      customerId: 'customer-1',
      now: DateTime(2026, 10, 8),
    );
    expect(order.receiverCollectionAmount, 0);
    expect(order.codCollectionAmount, 0);
    expect(order.goodsValue, 120000);
    expect(order.driverAdvanceAmount, 120000);
    expect(order.paymentMode, OrderPaymentMode.prepaid);
    expect(order.paymentStatus, OrderPaymentStatus.pending);
    final payload = buildOrderSubmissionPayload(order);
    expect(payload['delivery_fee_payer'], 'sender');
    expect(payload['cod_collection_amount'], 0);
    expect(payload['goods_value'], 120000);
  });

  test(
    'cash-on-delivery submits goods plus shipping without adding fees to advance',
    () {
      final controller = OrderFinanceFormController();
      addTearDown(controller.dispose);
      controller.setCodCollectionAmount(120000);

      final order = buildOrderFromForm(
        data: _form(controller),
        customerId: 'customer-1',
        now: DateTime(2026, 10, 8),
      );
      expect(order.driverAdvanceAmount, 120000);
      expect(order.receiverCollectionAmount, 145000);
      expect(order.driverNetEarning, 25000);
      expect(order.paymentMode, OrderPaymentMode.cod);
      expect(order.paymentStatus, OrderPaymentStatus.notRequired);
      expect(
        buildOrderSubmissionPayload(order)['delivery_fee_payer'],
        'recipient',
      );
    },
  );

  for (final collect in [false, true]) {
    testWidgets('confirmation shows actual collection for collect=$collect', (
      tester,
    ) async {
      final controller = OrderFinanceFormController();
      addTearDown(controller.dispose);
      controller.setCodCollectionAmount(120000);
      controller.setCollectCod(collect);
      if (!collect) controller.setGoodsValue(120000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OrderFinanceSummary(data: _form(controller))),
        ),
      );
      expect(
        find.text(collect ? 'Thanh toán khi nhận hàng' : 'Đã thanh toán'),
        findsOneWidget,
      );
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text(collect ? '145.000đ' : '0đ'), findsOneWidget);
      expect(find.textContaining('Tài xế ứng'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

OrderFormData _form(OrderFinanceFormController controller) => OrderFormData(
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
  paymentMethod: controller.collectCod ? 'cash' : 'vnpay',
  deliveryFeePayer: controller.deliveryFeePayer,
  goodsValue: controller.goodsValue,
  codCollectionAmount: controller.codCollectionAmount,
  deliveryFee: 25000,
  totalPrice: controller.codCollectionAmount + 25000.0,
  distanceMeters: 3000,
  feeBreakdown: DeliveryPricingPolicy.calculate(distanceMeters: 3000),
  deliveryEta: DeliveryEtaCalculator.calculate(distanceMeters: 3000),
);
