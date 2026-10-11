import 'dart:async';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/models/order_route_distance.dart';
import 'package:delivery_app/features/driver/screens/home/driver_home_strings.dart';
import 'package:delivery_app/features/driver/screens/home/providers/driver_order_route_distance_provider.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_available_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('both road legs and total fit $size with scale $scale', (
        tester,
      ) async {
        final boundary = GlobalKey();
        await _pumpOffer(
          tester,
          size: size,
          scale: scale,
          boundary: boundary,
          load: () async => const OrderRouteDistance(
            pickupMeters: 504.4,
            deliveryMeters: 4952.8,
          ),
        );
        await tester.pump();
        expect(find.text('5.5 km'), findsOneWidget);
        expect(find.text('Đến điểm lấy: 0.5 km'), findsOneWidget);
        expect(find.text('Lấy → giao: 5.0 km'), findsOneWidget);
        expect(find.text('4.2 km'), findsNothing);
        expect(
          find.text(DriverHomeStrings.routeDistanceSource),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('loading does not show a fabricated distance', (tester) async {
    final result = Completer<OrderRouteDistance>();
    await _pumpOffer(tester, load: () => result.future);
    expect(find.text(DriverHomeStrings.routeDistanceLoading), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('4.2 km'), findsNothing);
    expect(find.text(DriverHomeStrings.routeDistanceRetry), findsNothing);
    result.complete(
      const OrderRouteDistance(pickupMeters: 504.4, deliveryMeters: 4952.8),
    );
    await tester.pump();
    expect(find.text('5.5 km'), findsOneWidget);
  });

  testWidgets(
    'missing approach shows the known delivery leg and allows retry',
    (tester) async {
      var loads = 0;
      await _pumpOffer(
        tester,
        load: () async => ++loads == 1
            ? const OrderRouteDistance(deliveryMeters: 4952.8)
            : const OrderRouteDistance(
                pickupMeters: 504.4,
                deliveryMeters: 4952.8,
              ),
      );
      await tester.pump();
      expect(find.text('Đến điểm lấy: —'), findsOneWidget);
      expect(find.text('Lấy → giao: 5.0 km'), findsOneWidget);
      expect(
        find.text(DriverHomeStrings.routeDistanceUnavailable),
        findsOneWidget,
      );
      final total = tester.widget<Text>(
        find.byKey(const ValueKey('driver-route-total-distance')),
      );
      expect(total.data, '—');
      await tester.ensureVisible(
        find.text(DriverHomeStrings.routeDistanceRetry),
      );
      await tester.tap(find.text(DriverHomeStrings.routeDistanceRetry));
      await tester.pump();
      await tester.pump();
      expect(loads, 2);
      expect(find.text('5.5 km'), findsOneWidget);
      expect(
        find.text(DriverHomeStrings.routeDistanceUnavailable),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpOffer(
  WidgetTester tester, {
  required Future<OrderRouteDistance> Function() load,
  Size size = const Size(390, 844),
  double scale = 1,
  GlobalKey? boundary,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driverOrderRouteDistanceProvider.overrideWith((ref, request) => load()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              backgroundColor: const Color(0xFFFFFAF6),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: DriverAvailableOrderCard(
                        order: _order(),
                        actions: FilledButton(
                          onPressed: () {},
                          child: const Text('Nhận đơn'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

OrderModel _order() => OrderModel.fromJson({
  'id': '6e88bc98-f311-4883-a6af-54da68de825f',
  'tracking_code': 'GH-10205',
  'status': 'confirmed',
  'driver_net_earning': 33000,
  'delivery_fee': 33000,
  'pickup_address': '23, Đường DX124, Khu phố Tân An 3, Thành phố Hồ Chí Minh',
  'pickup_lat': 11.0313297901293,
  'pickup_lng': 106.618848428031,
  'delivery_address':
      '12, Đại lộ Bình Dương, Khu phố Định Hòa 1, Thành phố Hồ Chí Minh',
  'delivery_lat': 11.0104706299467,
  'delivery_lng': 106.646787682038,
});
