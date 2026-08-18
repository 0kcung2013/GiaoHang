import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/home/driver_home_strings.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_offer_countdown.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('counts down the persisted driver offer deadline', (
    tester,
  ) async {
    final deadline = tester.binding.clock.now().add(
      const Duration(seconds: 45),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOfferCountdown(
            expiresAt: deadline,
            now: tester.binding.clock.now,
          ),
        ),
      ),
    );

    expect(find.text(DriverHomeStrings.offerCountdownLabel), findsOneWidget);
    expect(find.text('00:45'), findsOneWidget);
    expect(find.text(DriverHomeStrings.offerAutoTransferHint), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Còn 45 giây để nhận đơn')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:44'), findsOneWidget);
  });

  testWidgets('announces automatic transfer when the offer expires', (
    tester,
  ) async {
    final deadline = tester.binding.clock.now().add(const Duration(seconds: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOfferCountdown(
            expiresAt: deadline,
            now: tester.binding.clock.now,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(DriverHomeStrings.offerExpiredLabel), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
  });

  testWidgets('available driver order card renders the offer countdown', (
    tester,
  ) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DriverOrderCard(
                order: _order(
                  now: now,
                  offerExpiresAt: now.add(const Duration(seconds: 45)),
                ),
                acceptDriverId: 'driver-1',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DriverOfferCountdown), findsOneWidget);
    expect(find.text(DriverHomeStrings.offerCountdownLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

OrderModel _order({required DateTime now, required DateTime offerExpiresAt}) {
  return OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    status: 'pending',
    pickupAddress: 'Điểm lấy hàng',
    pickupLat: 10.7,
    pickupLng: 106.6,
    deliveryAddress: 'Điểm giao hàng',
    deliveryLat: 10.8,
    deliveryLng: 106.7,
    createdAt: now,
    trackingCode: 'GH-00001',
    assignmentExpiresAt: now.add(const Duration(minutes: 15)),
    offeredDriverId: 'driver-1',
    offerExpiresAt: offerExpiresAt,
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
