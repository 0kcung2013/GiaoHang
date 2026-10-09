import 'dart:async';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/models/driver_wallet.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/providers/driver_wallet_providers.dart';
import 'package:delivery_app/core/services/customer_order_service.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:delivery_app/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:delivery_app/features/driver/screens/home/driver_home_strings.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_incoming_offer_overlay.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_card.dart';
import 'package:delivery_app/features/driver/screens/navigation/driver_accepted_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('offer subscription waits for and passes the server clock', () async {
    final clockSource = StreamController<DriverAcceptanceState>();
    final service = _OrderService();
    final container = ProviderContainer(
      overrides: [
        driverAcceptanceStateProvider.overrideWith(
          (ref, id) => clockSource.stream,
        ),
        customerOrderServiceProvider.overrideWithValue(service),
      ],
    );
    final subscription = container.listen(
      availableOrdersProvider('driver-1'),
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(service.offerSubscriptions, 0);
    final serverNow = DateTime.now().add(const Duration(minutes: 5));
    clockSource.add(DriverAcceptanceState(serverNow: serverNow));
    await container.read(availableOrdersProvider('driver-1').future);
    expect(service.offerSubscriptions, 1);
    expect(service.offerNow!().difference(serverNow).inSeconds, 0);
    subscription.close();
    container.dispose();
    await clockSource.close();
  });

  for (final overlay in [true, false]) {
    testWidgets(
      '${overlay ? 'takeover' : 'card'} blocks expired offers using server time',
      (tester) async {
        final deviceNow = DateTime.now();
        final service = _OrderService();
        await _pumpOffer(
          tester,
          order: _order(deviceNow, deviceNow.add(const Duration(seconds: 5))),
          clock: DriverAcceptanceState(
            serverNow: deviceNow.add(const Duration(seconds: 8)),
          ),
          service: service,
          overlay: overlay,
          viewport: const Size(320, 568),
          textScale: 1.6,
        );

        final button = tester.widget<FilledButton>(
          find.byWidgetPredicate((widget) => widget is FilledButton),
        );
        expect(button.onPressed, isNull);
        expect(find.text(DriverHomeStrings.offerExpiredLabel), findsWidgets);
        expect(service.acceptCalls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('accept disables at the deadline without a realtime event', (
    tester,
  ) async {
    final now = DateTime.now();
    final clock = _Clock(now);
    await _pumpOffer(
      tester,
      order: _order(now, now.add(const Duration(seconds: 2))),
      clock: clock,
      service: _OrderService(),
    );
    clock.current = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tap rechecks expiry even before the next frame', (tester) async {
    final now = DateTime.now();
    final clock = _Clock(now);
    final service = _OrderService();
    await _pumpOffer(
      tester,
      order: _order(now, now.add(const Duration(seconds: 2))),
      clock: clock,
      service: service,
    );
    clock.current = now.add(const Duration(seconds: 2));
    await tester.tap(find.text(DriverHomeStrings.incomingOfferAccept));
    await tester.pump();
    expect(service.acceptCalls, 0);
    expect(find.byType(DriverAcceptedOrderScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('countdown remains live when device time is ahead of server', (
    tester,
  ) async {
    final deviceNow = DateTime.now();
    final serverNow = deviceNow.subtract(const Duration(minutes: 5));
    await _pumpOffer(
      tester,
      order: _order(serverNow, serverNow.add(const Duration(seconds: 30))),
      clock: DriverAcceptanceState(serverNow: serverNow),
      service: _OrderService(),
    );
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text(DriverHomeStrings.offerExpiredLabel), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('successful accept opens details after realtime removes offer', (
    tester,
  ) async {
    final now = DateTime.now();
    final result = Completer<void>();
    final service = _OrderService(result: result.future);
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await _pumpOffer(
      tester,
      order: _order(now, now.add(const Duration(seconds: 45))),
      clock: DriverAcceptanceState(serverNow: now),
      service: service,
      visible: visible,
    );
    await tester.tap(find.text(DriverHomeStrings.incomingOfferAccept));
    await tester.pump();
    expect(service.acceptCalls, 1);
    visible.value = false;
    await tester.pump();
    result.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DriverAcceptedOrderScreen), findsOneWidget);
    expect(service.offerSubscriptions, greaterThan(1));
    expect(service.driverSubscriptions, greaterThan(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('server rejection stays visible after realtime removes offer', (
    tester,
  ) async {
    final now = DateTime.now();
    final result = Completer<void>();
    final service = _OrderService(result: result.future);
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await _pumpOffer(
      tester,
      order: _order(now, now.add(const Duration(seconds: 45))),
      clock: DriverAcceptanceState(serverNow: now),
      service: service,
      visible: visible,
    );
    await tester.tap(find.text(DriverHomeStrings.incomingOfferAccept));
    await tester.pump();
    visible.value = false;
    await tester.pump();
    result.completeError(Exception('Lời mời nhận đơn đã hết hạn.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Lời mời nhận đơn đã hết hạn.'), findsOneWidget);
    expect(find.byType(DriverAcceptedOrderScreen), findsNothing);
    expect(service.offerSubscriptions, greaterThan(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpOffer(
  WidgetTester tester, {
  required OrderModel order,
  required DriverAcceptanceState clock,
  required _OrderService service,
  bool overlay = true,
  ValueNotifier<bool>? visible,
  Size viewport = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driverAcceptanceStateProvider.overrideWith(
          (ref, id) => Stream.value(clock),
        ),
        customerOrderServiceProvider.overrideWithValue(service),
        driverWalletSummaryProvider.overrideWith(
          (ref) async => const DriverWalletSummary(
            availableBalance: 1000000,
            heldBalance: 0,
            todayIncome: 0,
          ),
        ),
        orderByIdProvider.overrideWith((ref, id) async => null),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              ref.watch(availableOrdersProvider('driver-1'));
              ref.watch(driverOrdersProvider('driver-1'));
              final offer = overlay
                  ? DriverIncomingOfferOverlay(
                      order: order,
                      driverUserId: 'driver-1',
                    )
                  : SingleChildScrollView(
                      child: DriverOrderCard(
                        order: order,
                        acceptDriverId: 'driver-1',
                      ),
                    );
              return visible == null
                  ? offer
                  : ValueListenableBuilder<bool>(
                      valueListenable: visible,
                      builder: (_, show, _) =>
                          show ? offer : const Text('Home'),
                    );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

OrderModel _order(DateTime createdAt, DateTime expiresAt) => OrderModel(
  id: 'order-1',
  customerId: 'customer-1',
  status: 'pending',
  pickupAddress: 'Điểm lấy',
  pickupLat: 10.7,
  pickupLng: 106.6,
  deliveryAddress: 'Điểm giao',
  deliveryLat: 10.8,
  deliveryLng: 106.7,
  createdAt: createdAt,
  updatedAt: createdAt,
  trackingCode: 'GH-001',
  offeredDriverId: 'driver-1',
  offerExpiresAt: expiresAt,
  deliveryFee: 30000,
  serviceType: 'standard',
  paymentMethod: 'cash',
);

class _OrderService implements CustomerOrderService {
  _OrderService({this.result});
  final Future<void>? result;
  int acceptCalls = 0;
  int offerSubscriptions = 0;
  int driverSubscriptions = 0;
  DateTime Function()? offerNow;

  @override
  Future<void> acceptOrder(
    String orderId,
    String driverId, {
    String? customerIdHint,
    String? orderCodeHint,
  }) async {
    acceptCalls++;
    if (result != null) await result;
  }

  @override
  Stream<List<OrderModel>> watchAvailableOrders({
    String? driverId,
    DateTime Function()? now,
  }) {
    offerSubscriptions++;
    offerNow = now;
    return Stream.value(const []);
  }

  @override
  Stream<List<OrderModel>> watchDriverOrders(String driverId) {
    driverSubscriptions++;
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Clock extends DriverAcceptanceState {
  _Clock(this.current) : super(serverNow: current);
  DateTime current;

  @override
  DateTime now() => current;
}
