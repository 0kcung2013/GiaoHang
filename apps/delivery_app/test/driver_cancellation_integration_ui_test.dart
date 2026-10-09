import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_strings.dart';
import 'package:delivery_app/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_data_body.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_home_layout.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_arrival_bar.dart';
import 'package:delivery_app/features/driver/widgets/driver_swipe_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final now = DateTime.utc(2026, 9, 27, 10);

  OrderModel order({DateTime? arrived}) => OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    driverId: 'driver-1',
    status: 'picking_up',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.8,
    pickupLng: 106.7,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.81,
    deliveryLng: 106.71,
    createdAt: now,
    updatedAt: now,
    trackingCode: 'GH-001',
    deliveryFee: 20000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    pickupArrivedAt: arrived,
  );

  testWidgets('arrival swipe is a distinct step before pickup confirmation', (
    tester,
  ) async {
    var arrivals = 0;
    var pickups = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverNavigationArrivalBar(
            order: order(),
            arrivedAtTarget: true,
            pickupConfirmed: false,
            isLoading: false,
            onPrimaryAction: () => pickups++,
            onConfirmPickupArrival: () => arrivals++,
          ),
        ),
      ),
    );
    expect(find.text(DriverCancellationStrings.swipeArrived), findsOneWidget);
    tester
        .widget<DriverSwipeAction>(find.byType(DriverSwipeAction))
        .onCompleted!();
    expect(arrivals, 1);
    expect(pickups, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverNavigationArrivalBar(
            order: order(arrived: now),
            arrivedAtTarget: true,
            pickupConfirmed: false,
            isLoading: false,
            onPrimaryAction: () => pickups++,
            onConfirmPickupArrival: () => arrivals++,
          ),
        ),
      ),
    );
    expect(find.text(DriverCancellationStrings.swipeArrived), findsNothing);
    tester
        .widget<DriverSwipeAction>(find.byType(DriverSwipeAction))
        .onCompleted!();
    expect(arrivals, 1);
    expect(pickups, 1);
  });

  testWidgets('arrival remains disabled outside the pickup geofence', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverNavigationArrivalBar(
            order: order(),
            arrivedAtTarget: false,
            pickupConfirmed: false,
            isLoading: false,
            onPrimaryAction: () {},
            onConfirmPickupArrival: () {},
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<DriverSwipeAction>(find.byType(DriverSwipeAction))
          .onCompleted,
      isNull,
    );
  });

  testWidgets('home has no availability switch after moving it to menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverByUserIdProvider.overrideWith(
            (ref, id) async => DriverModel(
              id: 'profile-1',
              userId: 'driver-1',
              isAvailable: false,
              updatedAt: now,
              totalDeliveries: 0,
            ),
          ),
          availableOrdersProvider.overrideWith((ref, id) => Stream.value([])),
          driverOrdersProvider.overrideWith((ref, id) => Stream.value([])),
          driverAcceptanceStateProvider.overrideWith(
            (ref, id) => Stream.value(DriverAcceptanceState(serverNow: now)),
          ),
          currentPositionProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DriverDashboardBody(
                userId: 'driver-1',
                email: null,
                layout: DriverHomeLayout.fromWidth(375),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Bật / Tắt app'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'home shows cooldown instead of availability and incoming offers',
    (tester) async {
      tester.view.physicalSize = const Size(375, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final locked = DriverAcceptanceState(
        serverNow: now,
        lockedUntil: now.add(const Duration(minutes: 30)),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverByUserIdProvider.overrideWith(
              (ref, id) async => DriverModel(
                id: 'profile-1',
                userId: 'driver-1',
                isAvailable: false,
                updatedAt: now,
                totalDeliveries: 0,
              ),
            ),
            availableOrdersProvider.overrideWith(
              (ref, id) =>
                  Stream.value([order().copyWith(status: 'confirmed')]),
            ),
            driverOrdersProvider.overrideWith((ref, id) => Stream.value([])),
            driverAcceptanceStateProvider.overrideWith(
              (ref, id) => Stream.value(locked),
            ),
            currentPositionProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DriverDashboardBody(
                  userId: 'driver-1',
                  email: null,
                  layout: DriverHomeLayout.fromWidth(375),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(DriverCancellationStrings.lockTitle), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Nhận đơn'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
