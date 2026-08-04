import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mounting and unmounting navigation does not mutate during build',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final showNavigation = ValueNotifier(true);
      addTearDown(showNavigation.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: ValueListenableBuilder<bool>(
            valueListenable: showNavigation,
            builder: (context, visible, _) {
              return MaterialApp(
                home: visible
                    ? DriverNavigationScreen(order: _order())
                    : const SizedBox.shrink(),
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull);

      showNavigation.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}

OrderModel _order() {
  final now = DateTime(2026, 7, 30, 10);
  return OrderModel(
    id: 'order-lifecycle',
    customerId: 'customer-1',
    driverId: 'driver-1',
    status: 'picking_up',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.773,
    pickupLng: 106.703,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.776,
    deliveryLng: 106.701,
    recipientName: 'Nguyễn Văn A',
    recipientPhone: '0900000000',
    createdAt: now,
    trackingCode: 'GH-LIFECYCLE',
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
