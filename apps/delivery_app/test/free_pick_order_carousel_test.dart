import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/free_pick/widgets/free_pick_order_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('swipe selects the next real order and keeps claim available', (
    tester,
  ) async {
    final orders = [_order('one'), _order('two')];
    final selected = <String>[];
    String? claimed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FreePickOrderCarousel(
              orders: orders,
              selectedOrderId: 'one',
              isClaiming: false,
              driverLat: 10.78,
              driverLng: 106.68,
              onSelected: (order) => selected.add(order.id),
              onClaim: (order) => claimed = order.id,
            ),
          ),
        ),
      ),
    );

    expect(find.text('GH-DEMO-one'), findsOneWidget);
    expect(find.textContaining('Hết hạn'), findsNothing);
    expect(find.textContaining('giây'), findsNothing);

    await tester.fling(
      find.byKey(const Key('free-pick-order-page-view')),
      const Offset(-420, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(selected, contains('two'));
    expect(find.text('GH-DEMO-two'), findsOneWidget);
    await tester.tap(find.text('Nhận đơn FreePick').hitTestable());
    expect(claimed, 'two');
  });
}

OrderModel _order(String id) {
  final now = DateTime(2099);
  return OrderModel(
    id: id,
    customerId: 'customer',
    status: 'confirmed',
    pickupAddress: 'Điểm lấy $id',
    pickupLat: id == 'one' ? 10.81 : 10.82,
    pickupLng: 106.68,
    deliveryAddress: 'Điểm giao $id',
    deliveryLat: id == 'one' ? 10.83 : 10.84,
    deliveryLng: 106.69,
    createdAt: now,
    trackingCode: 'GH-DEMO-$id',
    deliveryFee: 18000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    codCollectionAmount: 50000,
    driverNetEarning: 18000,
    driverAdvanceAmount: 50000,
    receiverCollectionAmount: 68000,
    assignmentExpiresAt: now,
    updatedAt: now,
  );
}
