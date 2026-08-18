import 'package:delivery_app/core/models/order_finance.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/services/order_assignment_service.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_finance_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('COD panel prioritizes advance collection and net earning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderFinancePanel(
            order: _order(OrderPaymentMode.cod),
            availableBalance: 50000,
          ),
        ),
      ),
    );

    expect(find.text('COD · CẦN ỨNG'), findsOneWidget);
    expect(find.text('120.000đ'), findsOneWidget);
    expect(find.text('Thu người nhận'), findsOneWidget);
    expect(find.text('145.000đ'), findsOneWidget);
    expect(find.text('Thực nhận'), findsOneWidget);
    expect(find.text('25.000đ'), findsOneWidget);
    expect(find.text('Nạp thêm 70.000đ'), findsOneWidget);
  });

  testWidgets('prepaid panel shows zero collection and net earning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderFinancePanel(
            order: _order(OrderPaymentMode.prepaid),
          ),
        ),
      ),
    );

    expect(find.text('PHÍ ĐÃ THANH TOÁN'), findsOneWidget);
    expect(find.text('0đ cần thu'), findsOneWidget);
    expect(find.text('Thực nhận 25.000đ'), findsOneWidget);
  });

  test('maps insufficient wallet response to a concise action', () {
    expect(
      OrderAssignmentService.acceptOrderErrorMessage(
        'PostgrestException: INSUFFICIENT_WALLET_BALANCE',
      ),
      'Số dư ví chưa đủ để ứng đơn này. Hãy nạp thêm rồi thử lại.',
    );
  });
}

OrderModel _order(OrderPaymentMode mode) {
  return OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    status: 'pending',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.1,
    pickupLng: 106.1,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.2,
    deliveryLng: 106.2,
    totalPrice: 145000,
    createdAt: DateTime.utc(2026, 8, 14),
    trackingCode: '1001',
    deliveryFee: 25000,
    serviceType: 'standard',
    paymentMethod: mode == OrderPaymentMode.cod ? 'cash' : 'wallet',
    paymentMode: mode,
    deliveryFeePayer: mode == OrderPaymentMode.cod
        ? DeliveryFeePayer.recipient
        : DeliveryFeePayer.sender,
    paymentStatus: mode == OrderPaymentMode.cod
        ? OrderPaymentStatus.notRequired
        : OrderPaymentStatus.paid,
    goodsValue: 120000,
    platformFeeRateBps: 0,
    platformFeeAmount: 0,
    driverNetEarning: 25000,
    driverAdvanceAmount: mode == OrderPaymentMode.cod ? 120000 : 0,
    receiverCollectionAmount: mode == OrderPaymentMode.cod ? 145000 : 0,
    updatedAt: DateTime.utc(2026, 8, 14),
  );
}
