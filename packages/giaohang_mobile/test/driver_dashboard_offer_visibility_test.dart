import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/order_route_distance.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:giaohang_mobile/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:giaohang_mobile/features/driver/screens/home/driver_home_strings.dart';
import 'package:giaohang_mobile/features/driver/screens/home/providers/driver_order_route_distance_provider.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_data_body.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_home_layout.dart';

import 'helpers/utraffic_capture_fonts.dart';

void main() {
  setUpAll(prepareUtrafficCaptureFonts);

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets('realtime offer never flashes on the dashboard at $size', (
      tester,
    ) async {
      final offers = StreamController<List<OrderModel>>.broadcast();
      addTearDown(offers.close);
      await _mount(tester, size: size, offers: offers.stream);
      offers.add([]);
      await tester.pumpAndSettle();
      expect(find.text(DriverHomeStrings.bannerTitle), findsOneWidget);

      offers.add([_order('offer', offered: true)]);
      // Check individual frames: a fullscreen route opens after the first frame.
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.text('Có đơn mới đang chờ'), findsNothing);
        expect(find.text('GH-offer'), findsNothing);
        expect(find.text('Nhận đơn'), findsNothing);
        expect(find.text(DriverHomeStrings.bannerTitle), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      if (size.width == 390 &&
          const bool.fromEnvironment('CAPTURE_DRIVER_DASHBOARD')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('dashboard-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            '../../.tmp/driver_dashboard_offer_visibility.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('dashboard keeps accepted work when an offer arrives', (
    tester,
  ) async {
    await _mount(
      tester,
      size: const Size(1024, 768),
      offers: Stream.value([_order('offer', offered: true)]),
      assigned: [_order('active')],
    );
    await tester.pumpAndSettle();
    expect(find.text('GH-active'), findsOneWidget);
    expect(find.text('GH-offer'), findsNothing);
    expect(find.text('Nhận đơn'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

final _now = DateTime.utc(2026, 11, 7, 7);

OrderModel _order(String id, {bool offered = false}) => OrderModel(
  id: id,
  customerId: 'customer',
  driverId: offered ? null : 'driver',
  status: offered ? 'confirmed' : 'assigned',
  offeredDriverId: offered ? 'driver' : null,
  offerExpiresAt: offered ? _now.add(const Duration(seconds: 45)) : null,
  pickupAddress: '12 Nguyễn Huệ, Quận 1',
  pickupLat: 10.77,
  pickupLng: 106.7,
  deliveryAddress: '85 Lê Lợi, Quận 1',
  deliveryLat: 10.78,
  deliveryLng: 106.71,
  createdAt: _now,
  updatedAt: _now,
  trackingCode: 'GH-$id',
  deliveryFee: 50000,
  serviceType: 'standard',
  paymentMethod: 'cash',
);

Future<void> _mount(
  WidgetTester tester, {
  required Size size,
  required Stream<List<OrderModel>> offers,
  List<OrderModel> assigned = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driverByUserIdProvider.overrideWith(
          (ref, id) async => DriverModel(
            id: 'profile',
            userId: 'driver',
            isAvailable: true,
            updatedAt: _now,
            totalDeliveries: 0,
          ),
        ),
        availableOrdersProvider.overrideWith((ref, id) => offers),
        driverOrdersProvider.overrideWith((ref, id) => Stream.value(assigned)),
        driverAcceptanceStateProvider.overrideWith(
          (ref, id) => Stream.value(DriverAcceptanceState(serverNow: _now)),
        ),
        currentPositionProvider.overrideWith((ref) async => null),
        driverOrderRouteDistanceProvider.overrideWith(
          (ref, request) async =>
              const OrderRouteDistance(pickupMeters: 500, deliveryMeters: 3500),
        ),
      ],
      child: MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('dashboard-capture'),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: DriverDashboardBody(
                userId: 'driver',
                email: null,
                layout: DriverHomeLayout.fromWidth(size.width),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
