import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/driver_nav_session_provider.dart';
import 'package:delivery_app/features/driver/cancellation/data/driver_cancellation_repository.dart';
import 'package:delivery_app/features/driver/cancellation/dialogs/driver_cancel_order_sheet.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_strings.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_card.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:delivery_app/features/driver/screens/orders/utils/driver_order_filter.dart';
import 'package:delivery_app/features/driver/screens/orders/widgets/driver_orders_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 9, 27, 10);
  final order = OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    driverId: 'driver-1',
    status: 'picking_up',
    pickupAddress: 'Cửa hàng · Điểm lấy',
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
  );
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('orders tab opens cancellation with fresh server eligibility', (
    tester,
  ) async {
    var reads = 0;
    final repository = DriverCancellationRepository(
      invoke: (name, params) async {
        expect(name, 'get_driver_order_cancellation_state');
        expect(params['p_order_id'], order.id);
        reads++;
        return {
          'status': 'picking_up',
          'pickup_confirmed': false,
          'pickup_arrived_at': now.toIso8601String(),
          'server_now': now.toIso8601String(),
        };
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverCancellationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DriverOrdersList(
              filter: DriverOrderFilter.active,
              orders: [order],
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text(DriverCancellationStrings.title));
    await tester.tap(find.text(DriverCancellationStrings.title));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.byType(DriverCancelOrderSheet), findsOneWidget);
    final store = find.ancestor(
      of: find.text(DriverCancellationStrings.storeClosed),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(store).onPressed, isNull);
    expect(find.textContaining('Mở sau'), findsOneWidget);
    await tester.ensureVisible(find.text(DriverCancellationStrings.keepOrder));
    await tester.tap(find.text(DriverCancellationStrings.keepOrder));
    await tester.pumpAndSettle();
    expect(find.byType(DriverCancelOrderSheet), findsNothing);
  });

  testWidgets('home card and navigation map have no cancellation entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DriverOrderCard(order: order)),
          ),
        ),
      ),
    );
    expect(find.text(DriverCancellationStrings.title), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: DriverNavigationView(
          order: order,
          map: const ColoredBox(color: Colors.white),
          arrivedAtTarget: true,
          isUpdatingStatus: false,
          onBack: () {},
          onFitMap: () {},
          onPrimaryAction: () {},
          onConfirmPickupArrival: () {},
        ),
      ),
    );
    expect(find.text(DriverCancellationStrings.title), findsNothing);
    expect(find.text(DriverCancellationStrings.swipeArrived), findsOneWidget);
  });

  testWidgets('navigation overlays fit mobile viewports and enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      for (final scale in [1.0, 1.6]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: DriverNavigationView(
                order: order,
                map: const ColoredBox(color: Colors.white),
                arrivedAtTarget: true,
                isUpdatingStatus: false,
                totalDistance: 0,
                totalDuration: 0,
                onBack: () {},
                onFitMap: () {},
                onPrimaryAction: () {},
                onContact: () {},
                onConfirmPickupArrival: () {},
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final action = tester.getRect(
          find.byKey(const Key('driver-navigation-primary-action')),
        );
        final instruction = tester.getRect(find.text('Đã đến điểm lấy'));
        expect(action.bottom, lessThanOrEqualTo(size.height));
        expect(action.top - instruction.bottom, greaterThan(size.height * 0.5));
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pickup custody hides cancellation even in orders tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DriverOrdersList(
              filter: DriverOrderFilter.active,
              orders: [order.copyWith(actualPickedUpAt: now)],
            ),
          ),
        ),
      ),
    );
    expect(find.text(DriverCancellationStrings.title), findsNothing);
  });

  testWidgets('personal cancellation clears navigation and returns home', (
    tester,
  ) async {
    var cancellations = 0;
    final repository = DriverCancellationRepository(
      invoke: (name, params) async {
        if (name == 'get_driver_order_cancellation_state') {
          return {
            'status': 'picking_up',
            'pickup_confirmed': false,
            'server_now': now.toIso8601String(),
          };
        }
        expect(name, 'cancel_driver_order');
        expect(params['p_reason'], 'personal');
        cancellations++;
        return {
          'order_id': order.id,
          'new_status': 'pending',
          'locked_until': now
              .add(const Duration(minutes: 30))
              .toIso8601String(),
          'server_now': now.toIso8601String(),
        };
      },
    );
    final container = ProviderContainer(
      overrides: [
        driverCancellationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final sessions = container.read(driverNavSessionsProvider.notifier);
    await sessions.ready;
    await sessions.upsert(
      DriverNavSession(
        orderId: order.id,
        status: order.status,
        lat: 10.8,
        lng: 106.7,
      ),
    );
    final router = GoRouter(
      initialLocation: '/orders',
      routes: [
        GoRoute(
          path: '/orders',
          builder: (_, _) => Scaffold(
            body: DriverOrdersList(
              filter: DriverOrderFilter.active,
              orders: [order],
            ),
          ),
        ),
        GoRoute(
          path: '/driver-home',
          builder: (_, _) => const Scaffold(body: Text('Driver home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.ensureVisible(find.text(DriverCancellationStrings.title));
    await tester.tap(find.text(DriverCancellationStrings.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DriverCancellationStrings.personal));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(DriverCancellationStrings.confirm));
    await tester.tap(find.text(DriverCancellationStrings.confirm));
    await tester.pumpAndSettle();
    expect(cancellations, 1);
    expect(container.read(driverNavSessionsProvider), isEmpty);
    expect(find.text('Driver home'), findsOneWidget);
  });
}
