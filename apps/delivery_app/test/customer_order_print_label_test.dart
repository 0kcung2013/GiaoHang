import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/widgets/order_print_label_action.dart';
import 'package:delivery_app/features/customer/screens/order/print_label/order_print_label_sheet.dart';
import 'package:delivery_app/features/customer/screens/order/print_label/order_print_label_strings.dart';
import 'package:delivery_app/features/customer/screens/order/print_label/order_shipping_label.dart';

void main() {
  testWidgets('customer previews and simulates printing a shipping label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: OrderPrintLabelAction(order: _order()),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(orderPrintLabelActionKey));
    await tester.pumpAndSettle();

    expect(find.byKey(orderPrintLabelSheetKey), findsOneWidget);
    expect(find.byKey(orderShippingLabelKey), findsOneWidget);
    expect(find.byKey(orderShippingLabelBarcodeKey), findsOneWidget);
    expect(find.text(OrderPrintLabelStrings.demoBadge), findsOneWidget);
    expect(find.text('GH-2026-001'), findsNWidgets(2));
    expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
    expect(find.textContaining('58 Lê Lợi'), findsOneWidget);
    expect(find.text('THU HỘ: 150.000đ'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(orderPrintLabelCopiesKey),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(OrderPrintLabelStrings.increaseCopies));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text('${OrderPrintLabelStrings.printAction} · 2 bản'),
      findsOne,
    );

    await tester.tap(find.byKey(orderPrintLabelButtonKey));
    await tester.pump();
    expect(find.text(OrderPrintLabelStrings.printingAction), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text(OrderPrintLabelStrings.printedAction), findsOneWidget);
    expect(find.text(OrderPrintLabelStrings.printSuccess), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shipping label preserves the 100 by 150 aspect ratio', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: OrderShippingLabel(order: _order()),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(orderShippingLabelKey));
    expect(size.width / size.height, closeTo(2 / 3, 0.001));
    expect(tester.takeException(), isNull);
  });
}

OrderModel _order() {
  final now = DateTime(2026, 9, 17, 10, 30);
  return OrderModel(
    id: 'order-12345678',
    customerId: 'customer-1',
    status: 'confirmed',
    pickupAddress: '12 Nguyễn Trãi, Quận 1',
    pickupLat: 10.76,
    pickupLng: 106.66,
    deliveryAddress: '58 Lê Lợi, Quận 3, Thành phố Hồ Chí Minh',
    deliveryLat: 10.78,
    deliveryLng: 106.68,
    totalPrice: 185000,
    note: 'Gọi người nhận trước khi giao.',
    createdAt: now,
    trackingCode: 'GH-2026-001',
    recipientName: 'Nguyễn Minh Anh',
    recipientPhone: '0901 234 567',
    itemName: 'Bánh kem sinh nhật',
    itemCategory: 'food',
    itemDescription: 'Giữ hộp thẳng và giao nhẹ tay',
    deliveryFee: 35000,
    serviceType: 'fragile',
    paymentMethod: 'cash',
    codCollectionAmount: 150000,
    receiverCollectionAmount: 150000,
    updatedAt: now,
  );
}
