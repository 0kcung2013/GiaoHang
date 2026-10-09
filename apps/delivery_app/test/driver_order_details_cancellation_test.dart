import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/location/location_ingest_service.dart';
import 'package:delivery_app/core/services/realtime_service.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/providers/driver_nav_session_provider.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:delivery_app/features/driver/cancellation/data/driver_cancellation_repository.dart';
import 'package:delivery_app/features/driver/cancellation/dialogs/driver_cancel_order_sheet.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_strings.dart';
import 'package:delivery_app/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_order_details_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _serverNow = DateTime.utc(2026, 10, 8, 12);

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('details uses the existing reason sheet and store wait', (
    tester,
  ) async {
    var reads = 0;
    final repository = DriverCancellationRepository(
      invoke: (name, params) async {
        expect(name, 'get_driver_order_cancellation_state');
        expect(params, {'p_order_id': 'order-1'});
        reads++;
        return {
          'status': 'picking_up',
          'pickup_confirmed': false,
          'pickup_arrived_at': _serverNow.toIso8601String(),
          'server_now': _serverNow.toIso8601String(),
        };
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverCancellationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(home: _view()),
      ),
    );
    await tester.ensureVisible(find.text(DriverCancellationStrings.title));
    await tester.tap(find.text(DriverCancellationStrings.title));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.byType(DriverCancelOrderSheet), findsOneWidget);
    final storeOption = find.ancestor(
      of: find.text(DriverCancellationStrings.storeClosed),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(storeOption).onPressed, isNull);
    expect(find.textContaining('Mở sau'), findsOneWidget);
    await tester.ensureVisible(find.text(DriverCancellationStrings.keepOrder));
    await tester.tap(find.text(DriverCancellationStrings.keepOrder));
    await tester.pumpAndSettle();
    expect(find.byType(DriverOrderDetailsContent), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('driver-open-map')));
    await tester.pump();
    expect(find.text(DriverCancellationStrings.title), findsNothing);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pump();
    expect(find.text(DriverCancellationStrings.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (status: 'picking_up', local: true, persisted: false),
    (status: 'picking_up', local: false, persisted: true),
    (status: 'delivering', local: false, persisted: false),
  ]) {
    testWidgets('details respects pickup custody $scenario', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _view(
              order: _order().copyWith(
                status: scenario.status,
                actualPickedUpAt: scenario.persisted ? _serverNow : null,
              ),
              pickupConfirmed: scenario.local,
            ),
          ),
        ),
      );
      expect(find.text(DriverCancellationStrings.title), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fresh server custody rejects cancellation from stale details', (
    tester,
  ) async {
    final repository = DriverCancellationRepository(
      invoke: (name, params) async {
        expect(name, 'get_driver_order_cancellation_state');
        return {
          'status': 'picking_up',
          'pickup_confirmed': true,
          'server_now': _serverNow.toIso8601String(),
        };
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverCancellationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(home: _view()),
      ),
    );
    await tester.ensureVisible(find.text(DriverCancellationStrings.title));
    await tester.tap(find.text(DriverCancellationStrings.title));
    await tester.pumpAndSettle();
    expect(find.byType(DriverCancelOrderSheet), findsNothing);
    expect(find.text(DriverCancellationStrings.unavailable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final rejected in [false, true]) {
    testWidgets(
      'cancellation from pushed navigation ${rejected ? 'keeps state on rejection' : 'returns home without restoring session'}',
      (tester) async {
        var cancellations = 0;
        final repository = DriverCancellationRepository(
          invoke: (name, params) async {
            if (name == 'get_driver_order_cancellation_state') {
              return {
                'status': 'picking_up',
                'pickup_confirmed': false,
                'server_now': _serverNow.toIso8601String(),
              };
            }
            expect(name, 'cancel_driver_order');
            expect(params, {'p_order_id': 'order-1', 'p_reason': 'personal'});
            cancellations++;
            if (rejected) throw Exception('ORDER_ALREADY_PICKED_UP');
            return {
              'order_id': 'order-1',
              'new_status': 'pending',
              'locked_until': _serverNow
                  .add(const Duration(minutes: 30))
                  .toIso8601String(),
              'server_now': _serverNow.toIso8601String(),
            };
          },
        );
        final sessions = DriverNavSessionsNotifier();
        await sessions.hydrate();
        await sessions.upsert(
          DriverNavSession(
            orderId: 'order-1',
            status: 'picking_up',
            lat: 10.773,
            lng: 106.703,
            locationMode: DriverLocationMode.demoHcm,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            driverCancellationRepositoryProvider.overrideWithValue(repository),
            driverNavSessionsProvider.overrideWith((ref) => sessions),
            realtimeServiceProvider.overrideWithValue(_NoopLocationServices()),
            locationIngestServiceProvider.overrideWithValue(
              _NoopLocationServices(),
            ),
            driverByUserIdProvider.overrideWith((ref, id) async => null),
            currentPositionProvider.overrideWith((ref) async => null),
            driverLocationModeProvider.overrideWith(
              (ref) => DriverLocationMode.demoHcm,
            ),
          ],
        );
        addTearDown(container.dispose);
        final navigator = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigator,
          initialLocation: '/driver-home',
          routes: [
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
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => DriverNavigationScreen(order: _order()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.ensureVisible(find.text(DriverCancellationStrings.title));
        await tester.tap(find.text(DriverCancellationStrings.title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(DriverCancellationStrings.personal));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text(DriverCancellationStrings.confirm),
        );
        await tester.tap(find.text(DriverCancellationStrings.confirm));
        await tester.pumpAndSettle();
        expect(cancellations, 1);
        if (rejected) {
          expect(find.byType(DriverCancelOrderSheet), findsOneWidget);
          expect(
            find.text(DriverCancellationStrings.unavailable),
            findsOneWidget,
          );
          expect(find.byType(DriverNavigationScreen), findsOneWidget);
          expect(
            container.read(driverNavSessionsProvider).containsKey('order-1'),
            isTrue,
          );
        } else {
          expect(find.byType(DriverNavigationScreen), findsNothing);
          expect(find.byType(DriverCancelOrderSheet), findsNothing);
          expect(find.text('Driver home'), findsOneWidget);
          expect(container.read(driverNavSessionsProvider), isEmpty);
          expect(container.read(activeDriverNavigationOrderProvider), isNull);
          expect(
            find.text(DriverCancellationStrings.supportCancelledTitle),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}

Widget _view({OrderModel? order, bool pickupConfirmed = false}) =>
    DriverNavigationView(
      showOrderDetails: true,
      order: order ?? _order(),
      pickupConfirmed: pickupConfirmed,
      map: const ColoredBox(color: Colors.white),
      arrivedAtTarget: false,
      isUpdatingStatus: false,
      onBack: () {},
      onFitMap: () {},
      onPrimaryAction: () {},
    );

OrderModel _order() => OrderModel(
  id: 'order-1',
  customerId: 'customer-1',
  driverId: 'driver-1',
  status: 'picking_up',
  trackingCode: 'GH-001',
  pickupAddress: 'Điểm lấy',
  pickupLat: 10.773,
  pickupLng: 106.703,
  deliveryAddress: 'Điểm giao',
  deliveryLat: 10.776,
  deliveryLng: 106.701,
  createdAt: _serverNow,
  updatedAt: _serverNow,
  deliveryFee: 30000,
  serviceType: 'standard',
  paymentMethod: 'cash',
);

class _NoopLocationServices implements RealtimeService, LocationIngestService {
  @override
  Future<void> broadcastDriverLocation({
    required String orderId,
    required double lat,
    required double lng,
  }) async {}

  @override
  Future<void> ingest({
    String? driverProfileId,
    String? driverUserId,
    String? orderId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    bool force = false,
    bool prioritySync = false,
    LocationIngestCoordinateSpace coordinateSpace =
        LocationIngestCoordinateSpace.rawGps,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
