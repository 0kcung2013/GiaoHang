import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support_orders/data/support_order_repository.dart';
import 'package:operations_web/features/support_orders/models/support_order.dart';
import 'package:operations_web/features/support_orders/screens/support_orders_screen.dart';

void main() {
  testWidgets('CSKH searches orders by tracking code and opens details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SupportOrdersScreen(repository: _FakeSupportOrderRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tra cứu đơn hàng'), findsOneWidget);
    expect(find.text('GH-1001'), findsOneWidget);
    expect(find.text('GH-2048'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('support-order-search')),
      '2048',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('GH-1001'), findsNothing);
    expect(find.text('GH-2048'), findsOneWidget);

    await tester.tap(find.text('GH-2048'));
    await tester.pumpAndSettle();

    expect(find.text('Hành trình'), findsOneWidget);
    expect(find.text('Lịch sử trạng thái'), findsOneWidget);
    expect(find.text('Tài xế đã nhận đơn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order lookup stays usable on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SupportOrdersScreen(repository: _FakeSupportOrderRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CSKH'), findsOneWidget);
    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.byKey(const Key('support-order-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeSupportOrderRepository implements SupportOrderRepository {
  static final _orders = [
    SupportOrder(
      id: 'order-1',
      trackingCode: 'GH-1001',
      status: 'delivered',
      pickupAddress: '12 Nguyễn Huệ, Quận 1',
      deliveryAddress: '20 Lê Lợi, Quận 1',
      createdAt: DateTime.utc(2026, 9, 16, 1),
      updatedAt: DateTime.utc(2026, 9, 16, 2),
      totalPrice: 75000,
      recipientName: 'Nguyễn An',
      customerId: 'customer-1',
    ),
    SupportOrder(
      id: 'order-2',
      trackingCode: 'GH-2048',
      status: 'delivering',
      pickupAddress: '1 Võ Văn Tần, Quận 3',
      deliveryAddress: '50 Phan Xích Long, Phú Nhuận',
      createdAt: DateTime.utc(2026, 9, 16, 3),
      updatedAt: DateTime.utc(2026, 9, 16, 4),
      totalPrice: 92000,
      deliveryFee: 32000,
      itemName: 'Tài liệu',
      recipientName: 'Lê Chi',
      recipientPhone: '0900000000',
      customerId: 'customer-2',
      driverId: 'driver-1',
      paymentMethod: 'cash',
    ),
  ];

  @override
  Future<List<SupportOrder>> fetchOrders({String trackingCode = ''}) async {
    final query = trackingCode.trim().toUpperCase();
    if (query.isEmpty) return _orders;
    return _orders
        .where((order) => order.trackingCode.toUpperCase().contains(query))
        .toList();
  }

  @override
  Future<List<SupportOrderStatusLog>> fetchStatusLogs(String orderId) async {
    return [
      SupportOrderStatusLog(
        status: 'assigned',
        title: 'Tài xế đã nhận đơn',
        createdAt: DateTime.utc(2026, 9, 16, 3, 30),
      ),
    ];
  }
}
