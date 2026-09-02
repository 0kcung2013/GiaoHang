import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/home/driver_home_strings.dart';
import 'package:delivery_app/features/driver/screens/home/utils/driver_order_distance.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_incoming_offer_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects a live offer only while the driver is on another tab', () {
    final order = _order();

    expect(selectIncomingOfferForTab(tabIndex: 0, offers: [order]), isNull);
    expect(
      selectIncomingOfferForTab(tabIndex: 2, offers: [order]),
      same(order),
    );
    expect(selectIncomingOfferForTab(tabIndex: 3, offers: const []), isNull);
  });

  testWidgets('new offer takeover fills the screen and exposes both actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: DriverIncomingOfferOverlay(
                order: _order(),
                driverUserId: 'driver-user-1',
                pickupDistanceMeters: 1200,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final overlay = find.byKey(const ValueKey('driver-incoming-offer-overlay'));
    expect(overlay, findsOneWidget);
    expect(tester.getSize(overlay), const Size(375, 812));
    expect(find.text(DriverHomeStrings.incomingOfferTitle), findsOneWidget);
    expect(find.text('12 Nguyễn Huệ, Quận 1'), findsOneWidget);
    expect(find.text('85 Lê Lợi, Quận 1'), findsOneWidget);
    expect(find.text(DriverHomeStrings.pickupDistanceLabel), findsOneWidget);
    expect(find.text(DriverHomeStrings.totalDistanceLabel), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    expect(
      find.text(
        distanceKilometersText(
          totalOrderDistanceFromPickup(
            order: _order(),
            pickupDistanceMeters: 1200,
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(DriverHomeStrings.incomingOfferAccept), findsOneWidget);
    expect(find.text(DriverHomeStrings.incomingOfferTransfer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

OrderModel _order() {
  final now = DateTime.now();
  return OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    status: 'confirmed',
    pickupAddress: '12 Nguyễn Huệ, Quận 1',
    pickupLat: 10.773,
    pickupLng: 106.703,
    deliveryAddress: '85 Lê Lợi, Quận 1',
    deliveryLat: 10.771,
    deliveryLng: 106.698,
    createdAt: now,
    trackingCode: 'GH-001',
    offerExpiresAt: now.add(const Duration(seconds: 45)),
    deliveryFee: 50000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
