import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/orders/utils/driver_order_filter.dart';
import 'package:delivery_app/features/driver/screens/orders/widgets/driver_orders_filter_bar.dart';
import 'package:delivery_app/features/driver/screens/orders/widgets/driver_orders_list.dart';
import 'package:delivery_app/features/driver/screens/orders/widgets/driver_orders_overview.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed history keeps only deliveries from the last four days', () {
    final now = DateTime.utc(2026, 9, 18, 12);
    final recent = _order(
      1,
      status: 'delivered',
      actualDeliveredAt: now.subtract(const Duration(days: 3, hours: 23)),
    );
    final expired = _order(
      2,
      status: 'delivered',
      actualDeliveredAt: now.subtract(const Duration(days: 4, seconds: 1)),
    );

    final result = DriverOrderFilter.completed.filter(
      availableOrders: const [],
      driverOrders: [expired, recent],
      now: now,
    );

    expect(result.map((order) => order.id), ['order-1']);
  });

  testWidgets('orders overview prioritizes the active delivery state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const DriverOrdersOverview(
          isAvailable: true,
          hasActiveOrder: true,
          availableCount: 0,
          activeCount: 1,
          completedCount: 12,
        ),
        textScale: 1.6,
      ),
    );

    expect(find.text('Ưu tiên chuyến đang chạy'), findsOneWidget);
    expect(find.text('ĐANG GIAO'), findsOneWidget);
    expect(find.text('Đơn mới'), findsOneWidget);
    expect(find.text('Đang chạy'), findsOneWidget);
    expect(find.text('Hoàn tất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('orders filters are localized and remain usable at text scale', (
    tester,
  ) async {
    DriverOrderFilter? selected;

    await tester.pumpWidget(
      _testApp(
        DriverOrdersFilterBar(
          selectedFilter: DriverOrderFilter.available,
          counts: const {
            DriverOrderFilter.available: 4,
            DriverOrderFilter.active: 1,
            DriverOrderFilter.completed: 8,
          },
          onChanged: (filter) => selected = filter,
        ),
        textScale: 1.6,
      ),
    );

    expect(find.text('Đơn mới'), findsOneWidget);
    expect(find.text('Đang chạy'), findsOneWidget);
    expect(find.text('Hoàn tất'), findsOneWidget);

    await tester.tap(find.text('Đang chạy'));
    expect(selected, DriverOrderFilter.active);
    expect(tester.takeException(), isNull);
  });

  testWidgets('orders list builds only cards near the visible viewport', (
    tester,
  ) async {
    final orders = List.generate(60, _order);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DriverOrdersList(
              filter: DriverOrderFilter.available,
              orders: orders,
            ),
          ),
        ),
      ),
    );

    final builtCards = find.byType(DriverOrderCard).evaluate().length;
    expect(builtCards, lessThan(20));
  });

  testWidgets('completed order opens a delivery detail sheet', (tester) async {
    final completed = _order(
      7,
      status: 'delivered',
      actualDeliveredAt: DateTime.utc(2026, 9, 18, 5, 9),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DriverOrdersList(
              filter: DriverOrderFilter.completed,
              orders: [completed],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('4 ngày gần đây'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('driver-completed-order-order-7')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết đơn hàng'), findsOneWidget);
    expect(find.text('Hành trình giao hàng'), findsOneWidget);
    expect(find.text('Thanh toán và thu nhập'), findsOneWidget);
  });
}

Widget _testApp(Widget child, {double textScale = 1}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(child: SizedBox(width: 375, child: child)),
      ),
    ),
  );
}

OrderModel _order(
  int index, {
  String status = 'pending',
  DateTime? actualDeliveredAt,
}) {
  final now = DateTime(2026, 8, 20, 10);
  return OrderModel(
    id: 'order-$index',
    customerId: 'customer-$index',
    status: status,
    pickupAddress: 'Điểm lấy hàng số $index',
    pickupLat: 10.77,
    pickupLng: 106.70,
    deliveryAddress: 'Điểm giao hàng số $index',
    deliveryLat: 10.78,
    deliveryLng: 106.71,
    createdAt: now,
    trackingCode: 'GH-$index',
    actualDeliveredAt: actualDeliveredAt,
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
