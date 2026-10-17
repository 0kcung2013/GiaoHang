import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/order_route_distance.dart';
import 'package:giaohang_mobile/core/utils/money_formatter.dart';
import 'package:giaohang_mobile/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:giaohang_mobile/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:giaohang_mobile/features/driver/screens/home/driver_home_strings.dart';
import 'package:giaohang_mobile/features/driver/screens/home/providers/driver_order_route_distance_provider.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_incoming_offer_overlay.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_order_card_components.dart';

import 'helpers/utraffic_capture_fonts.dart';

void main() {
  setUpAll(prepareUtrafficCaptureFonts);

  for (final config in [
    (const Size(390, 844), 1.0, '390'),
    (const Size(320, 568), 1.6, '320-large'),
    (const Size(844, 390), 1.6, '844-landscape'),
    (const Size(1024, 768), 1.0, '1024'),
  ]) {
    testWidgets(
      'offer content scrolls while actions stay visible at ${config.$3}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = config.$1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final now = DateTime.now();
        final order = OrderModel(
          id: 'offer-1',
          customerId: 'customer-1',
          status: 'confirmed',
          pickupAddress: '12 Nguyễn Huệ, phường Bến Nghé, Quận 1, TP.HCM',
          pickupLat: 10.77,
          pickupLng: 106.7,
          deliveryAddress: '85 Lê Lợi, phường Bến Thành, Quận 1, TP.HCM',
          deliveryLat: 10.78,
          deliveryLng: 106.71,
          createdAt: now,
          updatedAt: now,
          trackingCode: 'GH-102617',
          offeredDriverId: 'driver-1',
          offerExpiresAt: now.add(const Duration(seconds: 45)),
          estimatedPickupAt: DateTime.utc(2026, 10, 17, 8, 30),
          estimatedDeliveryAt: DateTime.utc(2026, 10, 17, 9, 10),
          deliveryFee: 140000,
          driverNetEarning: 126800,
          codCollectionAmount: 620000,
          driverAdvanceAmount: 620000,
          serviceType: 'standard',
          paymentMethod: 'cash',
        );
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: ProviderScope(
              overrides: [
                driverAcceptanceStateProvider.overrideWith(
                  (ref, id) =>
                      Stream.value(DriverAcceptanceState(serverNow: now)),
                ),
                driverOrderRouteDistanceProvider.overrideWith(
                  (ref, request) async => const OrderRouteDistance(
                    pickupMeters: 1200,
                    deliveryMeters: 8200,
                  ),
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(config.$2),
                    padding: const EdgeInsets.only(top: 28, bottom: 24),
                    viewPadding: const EdgeInsets.only(top: 28, bottom: 24),
                  ),
                  child: child!,
                ),
                home: DriverIncomingOfferOverlay(
                  order: order,
                  driverUserId: 'driver-1',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(DriverHomeStrings.incomingOfferEarning),
          findsOneWidget,
        );
        expect(find.text(formatVnd(order.driverNetEarning)), findsOneWidget);
        expect(find.text(DriverHomeStrings.incomingOfferCod), findsOneWidget);
        expect(
          find.text(formatVnd(order.codCollectionAmount)),
          findsNWidgets(2),
        );
        expect(
          find.text(DriverHomeStrings.incomingOfferWalletHold),
          findsOneWidget,
        );
        expect(
          find.text(formatVnd(order.driverAdvanceAmount)),
          findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);

        final accept = find.byType(DriverAcceptOrderButton);
        final skip = find.byType(DriverTransferOrderButton);
        final acceptBefore = tester.getRect(accept);
        final skipBefore = tester.getRect(skip);
        expect(acceptBefore.height, greaterThanOrEqualTo(48));
        expect(skipBefore.bottom, lessThanOrEqualTo(config.$1.height - 24));
        expect(acceptBefore.top, greaterThanOrEqualTo(28));
        if (config.$2 > 1) {
          await tester.ensureVisible(find.text(order.deliveryAddress));
          await tester.pumpAndSettle();
        }
        expect(tester.getRect(accept), acceptBefore);
        expect(tester.getRect(skip), skipBefore);
        expect(tester.takeException(), isNull);

        if (const bool.fromEnvironment('DRIVER_OFFER_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '../../.tmp/driver-fullscreen/offer-${config.$3}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
