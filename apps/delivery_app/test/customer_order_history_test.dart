import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/features/customer/screens/order/widgets/order_hub_list.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/customer/screens/order/utils/order_history_filter.dart';
import 'package:delivery_app/features/customer/screens/order/widgets/order_history_card.dart';
import 'package:delivery_app/features/customer/screens/order/widgets/order_hub_controls.dart';

OrderModel order(
  DateTime created, {
  String status = 'delivered',
  String code = 'GH-001',
}) => OrderModel(
  id: code,
  customerId: 'customer',
  status: status,
  pickupAddress: '12 Nguyễn Trãi, Quận 1',
  pickupLat: 10,
  pickupLng: 106,
  deliveryAddress: '85 Lê Văn Sỹ, Quận 3',
  deliveryLat: 11,
  deliveryLng: 107,
  createdAt: created,
  updatedAt: created,
  trackingCode: code,
  recipientName: 'Nguyễn Lan Anh',
  deliveryFee: 35000,
  serviceType: 'standard',
  paymentMethod: 'cash',
);

void main() {
  final now = DateTime(2026, 9, 27, 12);
  test(
    'date range includes the whole final day and excludes adjacent days',
    () {
      final filter = OrderHistoryFilter(
        period: OrderPeriod.custom,
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 15),
      );
      expect(filter.matches(order(DateTime(2026, 9, 1)), now), isTrue);
      expect(
        filter.matches(order(DateTime(2026, 9, 15, 23, 59, 59)), now),
        isTrue,
      );
      expect(
        filter.matches(order(DateTime(2026, 8, 31, 23, 59)), now),
        isFalse,
      );
      expect(filter.matches(order(DateTime(2026, 9, 16)), now), isFalse);
    },
  );
  test('quick periods use calendar days across month boundaries', () {
    final date = DateTime(2026, 3, 2, 12);
    const week = OrderHistoryFilter(period: OrderPeriod.week);
    expect(week.matches(order(DateTime(2026, 2, 24)), date), isTrue);
    expect(week.matches(order(DateTime(2026, 2, 23, 23, 59)), date), isFalse);
    const today = OrderHistoryFilter(period: OrderPeriod.today);
    expect(today.matches(order(DateTime(2026, 3, 2, 23)), date), isTrue);
    expect(today.matches(order(DateTime(2026, 3, 1, 23)), date), isFalse);
    const month = OrderHistoryFilter(period: OrderPeriod.month);
    expect(month.matches(order(DateTime(2026, 3, 1)), date), isTrue);
    expect(month.matches(order(DateTime(2026, 2, 28)), date), isFalse);
  });
  test(
    'search, status and dates combine, newest first without mutating input',
    () {
      final input = [
        order(DateTime(2026, 9, 1)),
        order(DateTime(2026, 9, 12), code: 'GH-002'),
        order(DateTime(2026, 9, 13), status: 'cancelled'),
      ];
      final result = filterCustomerOrders(
        input,
        history: true,
        query: 'lan anh',
        filter: const OrderHistoryFilter(
          period: OrderPeriod.month,
          status: OrderHistoryStatus.delivered,
        ),
        now: now,
      );
      expect(result.map((o) => o.trackingCode), ['GH-002', 'GH-001']);
      expect(input.first.trackingCode, 'GH-001');
      expect(
        filterCustomerOrders(
          input,
          history: true,
          query: 'không khớp',
          filter: const OrderHistoryFilter(),
          now: now,
        ),
        isEmpty,
      );
    },
  );
  test(
    'timed-out and in-progress orders remain discoverable in active tab',
    () {
      final input = [
        order(now, status: 'delivering'),
        order(now.subtract(const Duration(days: 1)), status: 'pending'),
        order(now),
        order(now, status: 'cancelled'),
      ];
      final active = filterCustomerOrders(
        input,
        history: false,
        query: '',
        filter: const OrderHistoryFilter(
          period: OrderPeriod.today,
          status: OrderHistoryStatus.cancelled,
        ),
        now: now,
      );
      expect(active.length, 2);
      expect(
        active.any((o) => o.effectiveStatusAt(now) == 'assignment_timeout'),
        isTrue,
      );
    },
  );
  test('groups use days for short periods and months for all history', () {
    expect(const OrderHistoryFilter().groupLabel(now), 'Tháng 9/2026');
    expect(
      const OrderHistoryFilter(period: OrderPeriod.week).groupLabel(now),
      '27/09/2026',
    );
  });

  testWidgets('empty history keeps date filters usable on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerOrdersProvider('customer').overrideWith((ref) async => []),
          ordersRealtimeProvider('customer').overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OrderHubList(
              customerId: 'customer',
              history: true,
              query: '',
              filter: const OrderHistoryFilter(),
              onFilter: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch sử đơn hàng'), findsOneWidget);
    expect(find.text('Chọn ngày'), findsOneWidget);
  });

  testWidgets('history list groups completed orders and hides active orders', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerOrdersProvider('customer').overrideWith(
            (ref) async => [
              order(DateTime(2026, 8, 31), code: 'OLD'),
              order(DateTime(2026, 9, 1), code: 'NEW'),
              order(now, status: 'delivering', code: 'ACTIVE'),
            ],
          ),
          ordersRealtimeProvider('customer').overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OrderHubList(
              customerId: 'customer',
              history: true,
              query: '',
              filter: const OrderHistoryFilter(),
              onFilter: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tháng 9/2026'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('ACTIVE'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Tháng 8/2026'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tháng 8/2026'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets('history card and controls fit $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.6),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    OrderHubControls(
                      controller: controller,
                      history: true,
                      onSearch: (_) {},
                      onTab: (_) {},
                      onCreate: () {},
                    ),
                    OrderHistoryControls(
                      filter: OrderHistoryFilter(
                        period: OrderPeriod.custom,
                        start: DateTime(2026, 8, 1),
                        end: DateTime(2026, 9, 27),
                      ),
                      onChanged: (_) {},
                    ),
                    OrderHistoryCard(
                      order: order(now),
                      onTap: () => tapped = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('GH-001'));
      await tester.tap(find.text('GH-001'));
      expect(tapped, isTrue);
      expect(find.text('35.000đ'), findsOneWidget);
    });
  }
  testWidgets(
    'pick one day, clear it, and cancel range without changing filter',
    (tester) async {
      var filter = const OrderHistoryFilter();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => OrderHistoryControls(
                filter: filter,
                onChanged: (value) => setState(() => filter = value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Chọn ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Một ngày'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(filter.period, OrderPeriod.custom);
      expect(filter.start, filter.end);
      await tester.tap(find.byTooltip('Bỏ lọc ngày'));
      await tester.pumpAndSettle();
      expect(filter.period, OrderPeriod.all);
      await tester.tap(find.text('Chọn ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khoảng ngày'));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(filter.period, OrderPeriod.all);
    },
  );
}
