import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/order_route_distance.dart';
import 'package:giaohang_mobile/features/driver/screens/home/driver_home_strings.dart';
import 'package:giaohang_mobile/features/driver/screens/home/providers/driver_order_route_distance_provider.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_incoming_offer_overlay.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_order_card.dart';
import 'package:giaohang_mobile/features/driver/screens/home/providers/driver_offer_acceptance_provider.dart';
import 'package:giaohang_mobile/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:giaohang_mobile/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:giaohang_mobile/core/widgets/stored_media_image.dart';
import 'package:giaohang_mobile/core/utils/money_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('selects an offer on every tab including the overview', () {
    final order = _order();

    for (var tab = 0; tab < 5; tab++) {
      expect(
        selectIncomingOfferForTab(tabIndex: tab, offers: [order]),
        same(order),
      );
    }
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
        overrides: [
          driverOrderRouteDistanceProvider.overrideWith(
            (ref, request) async => const OrderRouteDistance(
              pickupMeters: 504.4,
              deliveryMeters: 4952.8,
            ),
          ),
          driverAcceptanceStateProvider.overrideWith(
            (ref, id) =>
                Stream.value(DriverAcceptanceState(serverNow: DateTime.now())),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: DriverIncomingOfferOverlay(
                order: _order(),
                driverUserId: 'driver-user-1',
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
    expect(find.text(DriverHomeStrings.totalDistanceLabel), findsOneWidget);
    expect(find.text(formatVnd(_order().driverNetEarning)), findsOneWidget);
    expect(find.text('5.5 km'), findsOneWidget);
    expect(find.text('Đến điểm lấy: 504 m'), findsOneWidget);
    expect(find.text('Lấy → giao: 5.0 km'), findsOneWidget);
    expect(find.text(_order().itemName!), findsNothing);
    expect(find.text(_order().itemDescription!), findsNothing);
    expect(find.byType(StoredMediaImage), findsNothing);
    expect(find.text(DriverHomeStrings.incomingOfferAccept), findsOneWidget);
    expect(find.text(DriverHomeStrings.incomingOfferSkip), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driver-incoming-offer-cargo')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final overlay in [true, false]) {
    testWidgets(
      'accept from ${overlay ? 'overlay' : 'card'} uses the GPS confirmation gate',
      (tester) async {
        final order = _order().copyWith(offeredDriverId: 'driver-user-1');
        var calls = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              driverOfferAcceptanceProvider.overrideWithValue((
                actualOrder,
                id, {
                orderCodeHint,
              }) async {
                expect(actualOrder.id, order.id);
                expect(id, 'driver-user-1');
                calls++;
                throw Exception('GPS chưa được xác nhận');
              }),
              driverOrderRouteDistanceProvider.overrideWith(
                (ref, request) async => const OrderRouteDistance(
                  pickupMeters: 30,
                  deliveryMeters: 600,
                ),
              ),
              driverAcceptanceStateProvider.overrideWith(
                (ref, id) => Stream.value(
                  DriverAcceptanceState(serverNow: DateTime.now()),
                ),
              ),
            ],
            child: MaterialApp(
              home: overlay
                  ? DriverIncomingOfferOverlay(
                      order: order,
                      driverUserId: 'driver-user-1',
                    )
                  : Scaffold(
                      body: SingleChildScrollView(
                        child: DriverOrderCard(
                          order: order,
                          acceptDriverId: 'driver-user-1',
                        ),
                      ),
                    ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final accept = find.text(DriverHomeStrings.incomingOfferAccept);
        await tester.ensureVisible(accept);
        await tester.tap(accept);
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text('GPS chưa được xác nhận'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
    itemName: 'Hộp bánh sinh nhật',
    itemCategory: 'food',
    itemDescription: 'Mô tả chỉ hiện sau khi nhận',
    itemImageUrl: 'https://example.com/cargo.png',
    driverNetEarning: 42500,
    offerExpiresAt: now.add(const Duration(seconds: 45)),
    deliveryFee: 50000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
