import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/features/customer/screens/tracking/tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tracking empty state fits a narrow customer screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: TrackingScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Theo dõi đơn'), findsOneWidget);
    expect(find.text('Nhập mã vận đơn'), findsOneWidget);
    expect(find.text('Nhập mã đơn hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracked order prioritizes status and expandable details', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderByTrackingCodeProvider.overrideWith(
            (ref, trackingCode) async => _cancelledOrder,
          ),
          trackedOrderRealtimeProvider.overrideWith((ref, request) async {}),
          orderStatusLogsProvider.overrideWith(
            (ref, orderId) async => const [],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TrackingScreen(initialTrackingCode: 'GH-2026-001'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRẠNG THÁI HIỆN TẠI'), findsOneWidget);
    expect(find.text('Đã huỷ'), findsWidgets);
    expect(find.text('Đơn đã kết thúc'), findsOneWidget);
    expect(find.text('Hành trình đơn hàng'), findsOneWidget);
    expect(find.text('Thông tin gói hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _cancelledOrder = OrderModel(
  id: 'order-2026-001',
  customerId: 'customer-1',
  status: 'cancelled',
  pickupAddress: '12 Nguyễn Huệ, Quận 1',
  pickupLat: 10.773,
  pickupLng: 106.704,
  deliveryAddress: '45 Lê Lợi, Quận 1',
  deliveryLat: 10.775,
  deliveryLng: 106.7,
  createdAt: DateTime.utc(2026, 9, 3, 2),
  trackingCode: 'GH-2026-001',
  cancelledAt: DateTime.utc(2026, 9, 3, 3),
  deliveryFee: 32000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  updatedAt: DateTime.utc(2026, 9, 3, 3),
);
