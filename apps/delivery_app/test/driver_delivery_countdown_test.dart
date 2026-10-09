import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_delivery_countdown.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_arrival_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'counts from deadline, crosses expiry and accepts a new deadline',
    (tester) async {
      var now = DateTime.utc(2026, 10, 2, 12);
      final initial = now.add(const Duration(minutes: 18));
      Future<void> show(DateTime? deadline) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverDeliveryCountdown(deadline: deadline, now: () => now),
          ),
        ),
      );
      await show(initial);
      expect(find.text('Còn 18 phút'), findsOneWidget);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Còn 17 phút'), findsOneWidget);
      now = initial.subtract(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Còn 1 phút'), findsOneWidget);
      now = initial;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Quá hạn 0 phút'), findsOneWidget);
      now = initial.add(const Duration(minutes: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Quá hạn 3 phút'), findsOneWidget);
      await show(now.add(const Duration(minutes: 25)));
      expect(find.text('Còn 25 phút'), findsOneWidget);
      await show(null);
      expect(find.text('Chưa có hạn giao'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('arrival bar shows countdown only for active delivery states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final status in [
      'assigned',
      'picking_up',
      'delivering',
      'delivered',
      'cancelled',
    ]) {
      final now = DateTime.now();
      final order = OrderModel(
        id: 'order-1',
        customerId: 'customer',
        status: status,
        pickupAddress: 'Điểm lấy',
        pickupLat: 10,
        pickupLng: 106,
        deliveryAddress: 'Điểm giao',
        deliveryLat: 10.1,
        deliveryLng: 106.1,
        createdAt: now,
        updatedAt: now,
        trackingCode: 'GH-1',
        deliveryFee: 20000,
        serviceType: 'standard',
        paymentMethod: 'cash',
        estimatedDeliveryAt: now.add(const Duration(minutes: 18)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DriverNavigationArrivalBar(
                  order: order,
                  arrivedAtTarget: false,
                  pickupConfirmed: false,
                  isLoading: false,
                  onPrimaryAction: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byType(DriverDeliveryCountdown),
        status == 'delivered' || status == 'cancelled'
            ? findsNothing
            : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
