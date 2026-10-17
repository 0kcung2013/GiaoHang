import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/order_route_distance.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/services/customer_order_service.dart';
import 'package:giaohang_mobile/features/driver/cancellation/data/driver_cancellation_repository.dart';
import 'package:giaohang_mobile/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:giaohang_mobile/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:giaohang_mobile/features/driver/screens/home/driver_home_strings.dart';
import 'package:giaohang_mobile/features/driver/screens/home/providers/driver_offer_acceptance_provider.dart';
import 'package:giaohang_mobile/features/driver/screens/home/providers/driver_order_route_distance_provider.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_incoming_offer_host.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_incoming_offer_overlay.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/driver_accepted_order_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (var tab = 0; tab < 5; tab++) {
    testWidgets('full screen on tab $tab; dismissal keeps that tab and state', (
      tester,
    ) async {
      final fixture = _Fixture(tab: tab);
      await fixture.mount(tester);
      await tester.tap(find.text('Counter 0'));
      fixture.offer.value = fixture.newOffer();
      await tester.pumpAndSettle();
      final overlay = find.byKey(
        const ValueKey('driver-incoming-offer-overlay'),
      );
      expect(tester.getSize(overlay), const Size(390, 844));
      expect(find.text('Tab $tab').hitTestable(), findsNothing);
      fixture.offer.value = null;
      await tester.pumpAndSettle();
      expect(overlay, findsNothing);
      expect(find.text('Tab $tab'), findsOneWidget);
      expect(find.text('Counter 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'covers a pushed page; duplicate updates do not stack or alert twice',
    (tester) async {
      final fixture = _Fixture();
      final feedback = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          feedback.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await fixture.mount(tester);
      fixture.navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Page underneath'))),
        ),
      );
      await tester.pumpAndSettle();
      fixture.offer.value = fixture.newOffer();
      await tester.pumpAndSettle();
      fixture.offer.value = fixture.offer.value!.copyWith(
        note: 'Updated snapshot',
      );
      await tester.pumpAndSettle();
      expect(fixture.observer.offerPushes, 1);
      expect(
        feedback.where((call) => call == 'SystemSound.play'),
        hasLength(1),
      );
      expect(
        feedback.where((call) => call == 'HapticFeedback.vibrate'),
        hasLength(1),
      );
      expect(find.text('Page underneath').hitTestable(), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DriverIncomingOfferOverlay), findsOneWidget);
      fixture.offer.value = null;
      await tester.pumpAndSettle();
      expect(find.text('Page underneath'), findsOneWidget);
      fixture.offer.value = fixture.newOffer();
      await tester.pumpAndSettle();
      expect(fixture.observer.offerPushes, 2);
      expect(
        feedback.where((call) => call == 'SystemSound.play'),
        hasLength(1),
      );
      expect(
        feedback.where((call) => call == 'HapticFeedback.vibrate'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final assignmentFirst in [false, true]) {
    testWidgets(
      'closes at ${assignmentFirst ? 'assignment' : 'offer'} expiry without realtime',
      (tester) async {
        final fixture = _Fixture();
        await fixture.mount(tester);
        fixture.offer.value = fixture.newOffer().copyWith(
          offerExpiresAt: fixture.clock.current.add(
            Duration(seconds: assignmentFirst ? 45 : 2),
          ),
          assignmentExpiresAt: fixture.clock.current.add(
            Duration(seconds: assignmentFirst ? 2 : 300),
          ),
        );
        await tester.pumpAndSettle();
        fixture.clock.current = fixture.clock.current.add(
          const Duration(seconds: 2),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byType(DriverIncomingOfferOverlay), findsNothing);
        expect(find.text('Tab 2'), findsOneWidget);
        expect(fixture.orders.transfers, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'removed offer closes its confirmation sheet but preserves older dialog',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      showDialog<void>(
        context: fixture.navigator.currentContext!,
        builder: (_) => const Dialog(child: Text('Earlier dialog')),
      );
      await tester.pumpAndSettle();
      fixture.offer.value = fixture.newOffer();
      await tester.pumpAndSettle();
      await tester.tap(find.text(DriverHomeStrings.incomingOfferSkip));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('confirm-driver-offer-transfer')),
        findsOneWidget,
      );
      fixture.offer.value = null;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('confirm-driver-offer-transfer')),
        findsNothing,
      );
      expect(find.byType(DriverIncomingOfferOverlay), findsNothing);
      expect(find.text('Earlier dialog'), findsOneWidget);
      expect(fixture.orders.transfers, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed skip calls existing transfer and keeps cached offer closed',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      fixture.offer.value = fixture.newOffer();
      await tester.pumpAndSettle();
      await tester.tap(find.text(DriverHomeStrings.incomingOfferSkip));
      await tester.pumpAndSettle();
      expect(fixture.orders.transfers, 0);
      await tester.tap(find.byKey(const Key('confirm-driver-offer-transfer')));
      await tester.pumpAndSettle();
      expect(fixture.orders.transfers, 1);
      expect(find.byType(DriverIncomingOfferOverlay), findsNothing);
      fixture.offer.value = fixture.offer.value!.copyWith(note: 'Stale event');
      await tester.pumpAndSettle();
      expect(fixture.observer.offerPushes, 1);
      expect(find.text('Tab 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final realtimeFirst in [false, true]) {
    testWidgets(
      'accept opens root order page; realtime removal first=$realtimeFirst',
      (tester) async {
        final fixture = _Fixture();
        final result = Completer<void>();
        fixture.acceptResult = result.future;
        await fixture.mount(tester);
        fixture.offer.value = fixture.newOffer();
        await tester.pumpAndSettle();
        await tester.tap(find.text(DriverHomeStrings.incomingOfferAccept));
        await tester.pump();
        expect(fixture.acceptCalls, 1);
        if (realtimeFirst) {
          fixture.offer.value = null;
          await tester.pumpAndSettle();
        }
        result.complete();
        await tester.pumpAndSettle();
        expect(find.byType(DriverAcceptedOrderScreen), findsOneWidget);
        expect(find.byType(DriverIncomingOfferOverlay), findsNothing);
        fixture.navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('Tab 2'), findsOneWidget);
        expect(find.byType(DriverIncomingOfferOverlay), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'server failure is visible after realtime removes the modal route',
    (tester) async {
      final fixture = _Fixture();
      final result = Completer<void>();
      fixture.acceptResult = result.future;
      await fixture.mount(tester);
      fixture.offer.value = fixture.newOffer();
      await tester.pumpAndSettle();
      await tester.tap(find.text(DriverHomeStrings.incomingOfferAccept));
      await tester.pump();
      fixture.offer.value = null;
      await tester.pumpAndSettle();
      result.completeError(Exception('Lời mời nhận đơn đã hết hạn.'));
      await tester.pumpAndSettle();
      expect(find.text('Lời mời nhận đơn đã hết hạn.'), findsOneWidget);
      expect(find.byType(DriverAcceptedOrderScreen), findsNothing);
      expect(find.text('Tab 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('skip failure keeps the offer actionable', (tester) async {
    final fixture = _Fixture();
    fixture.orders.error = Exception('Mất kết nối, vui lòng thử lại.');
    await fixture.mount(tester);
    fixture.offer.value = fixture.newOffer();
    await tester.pumpAndSettle();
    await tester.tap(find.text(DriverHomeStrings.incomingOfferSkip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-driver-offer-transfer')));
    await tester.pumpAndSettle();
    expect(find.byType(DriverIncomingOfferOverlay), findsOneWidget);
    expect(
      find.text('Mất kết nối, vui lòng thử lại.').hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired, other-driver and missing-clock offers never open', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.mount(tester);
    fixture.offer.value = fixture.newOffer().copyWith(
      offeredDriverId: 'another-driver',
    );
    await tester.pumpAndSettle();
    fixture.offer.value = fixture.newOffer().copyWith(
      offerExpiresAt: fixture.clock.current,
    );
    await tester.pumpAndSettle();
    fixture.hasClock.value = false;
    fixture.offer.value = fixture.newOffer();
    await tester.pumpAndSettle();
    expect(fixture.observer.offerPushes, 0);
    expect(find.byType(DriverIncomingOfferOverlay), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  _Fixture({this.tab = 2});
  final int tab;
  final clock = _Clock(DateTime.utc(2026, 10, 17, 7));
  final offer = ValueNotifier<OrderModel?>(null);
  final hasClock = ValueNotifier(true);
  final navigator = GlobalKey<NavigatorState>();
  final observer = _Observer();
  final orders = _Orders();
  Future<void>? acceptResult;
  int acceptCalls = 0;

  OrderModel newOffer() => OrderModel(
    id: 'offer-1',
    customerId: 'customer-1',
    status: 'confirmed',
    pickupAddress: '12 Nguyễn Huệ, Quận 1',
    pickupLat: 10.77,
    pickupLng: 106.7,
    deliveryAddress: '85 Lê Lợi, Quận 1',
    deliveryLat: 10.78,
    deliveryLng: 106.71,
    createdAt: clock.current,
    updatedAt: clock.current,
    trackingCode: 'GH-001',
    offeredDriverId: 'driver-1',
    offerExpiresAt: clock.current.add(const Duration(seconds: 45)),
    deliveryFee: 50000,
    driverNetEarning: 42500,
    serviceType: 'standard',
    paymentMethod: 'cash',
  );

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      offer.dispose();
      hasClock.dispose();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverAcceptanceStateProvider.overrideWith(
            (ref, id) => Stream.value(clock),
          ),
          driverOrderRouteDistanceProvider.overrideWith(
            (ref, request) async => const OrderRouteDistance(
              pickupMeters: 500,
              deliveryMeters: 3500,
            ),
          ),
          customerOrderServiceProvider.overrideWithValue(orders),
          availableOrdersProvider.overrideWith(
            (ref, id) => Stream.value(const []),
          ),
          driverOrdersProvider.overrideWith(
            (ref, id) => Stream.value(const []),
          ),
          orderByIdProvider.overrideWith((ref, id) async => null),
          driverOfferAcceptanceProvider.overrideWithValue((
            order,
            id, {
            orderCodeHint,
          }) async {
            acceptCalls++;
            if (acceptResult != null) await acceptResult;
          }),
          driverCancellationRepositoryProvider.overrideWithValue(
            DriverCancellationRepository(
              invoke: (name, params) async => {
                'server_now': clock.current.toIso8601String(),
                'locked_until': null,
              },
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: Scaffold(
            body: Stack(
              children: [
                _TabProbe(tab: tab),
                ValueListenableBuilder<bool>(
                  valueListenable: hasClock,
                  builder: (_, ready, _) => ValueListenableBuilder<OrderModel?>(
                    valueListenable: offer,
                    builder: (_, order, _) => DriverIncomingOfferHost(
                      order: order,
                      driverUserId: 'driver-1',
                      now: ready ? clock.now : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _TabProbe extends StatefulWidget {
  const _TabProbe({required this.tab});
  final int tab;
  @override
  State<_TabProbe> createState() => _TabProbeState();
}

class _TabProbeState extends State<_TabProbe> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Tab ${widget.tab}'),
        TextButton(
          onPressed: () => setState(() => count++),
          child: Text('Counter $count'),
        ),
      ],
    ),
  );
}

class _Observer extends NavigatorObserver {
  int offerPushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == DriverHomeStrings.incomingOfferRoute) {
      offerPushes++;
    }
  }
}

class _Clock extends DriverAcceptanceState {
  _Clock(this.current) : super(serverNow: current);
  DateTime current;
  @override
  DateTime now() => current;
}

class _Orders implements CustomerOrderService {
  int transfers = 0;
  Object? error;
  @override
  Future<String?> transferOrder(String orderId, String driverUserId) async {
    transfers++;
    if (error != null) throw error!;
    return 'next-driver';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
