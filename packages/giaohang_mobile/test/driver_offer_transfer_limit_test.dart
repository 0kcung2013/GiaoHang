import 'dart:async';

import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/order_route_distance.dart';
import 'package:giaohang_mobile/features/driver/screens/home/providers/driver_order_route_distance_provider.dart';
import 'package:giaohang_mobile/core/models/driver_wallet.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/driver_wallet_providers.dart';
import 'package:giaohang_mobile/core/services/customer_order_service.dart';
import 'package:giaohang_mobile/features/driver/cancellation/data/driver_cancellation_repository.dart';
import 'package:giaohang_mobile/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:giaohang_mobile/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:giaohang_mobile/features/driver/cancellation/widgets/driver_acceptance_lock_card.dart';
import 'package:giaohang_mobile/features/driver/offer_transfer/driver_offer_transfer_strings.dart';
import 'package:giaohang_mobile/features/driver/offer_transfer/models/driver_offer_transfer_state.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_incoming_offer_overlay.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_order_card.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_order_card_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('old acceptance responses do not invent a transfer quota', () {
    final state = DriverAcceptanceState.fromJson({
      'server_now': '2026-10-09T10:00:00Z',
      'locked_until': null,
    });
    expect(state.transfers, isNull);
    expect(state.nextRefreshAt, isNull);
  });

  test('server snapshot restores quota and refreshes at the next expiry', () {
    final state = DriverAcceptanceState.fromJson({
      'server_now': '2026-10-09T10:00:00Z',
      'locked_until': '2026-10-09T10:30:00Z',
      'lock_reason': 'offer_transfers',
      'transfer_count': 3,
      'transfer_next_expiry_at': '2026-10-09T10:02:00Z',
    });
    expect(state.isLocked, isTrue);
    expect(state.transfers!.remaining, 1);
    expect(state.transfers!.isLastTransfer, isTrue);
    expect(state.lockReason, DriverOfferTransferState.lockReason);
    expect(state.nextRefreshAt, DateTime.utc(2026, 10, 9, 10, 2));
  });

  for (final overlay in [true, false]) {
    testWidgets('cancel fourth transfer does not call RPC; overlay=$overlay', (
      tester,
    ) async {
      final fixture = _Fixture(count: 3);
      await fixture.mount(tester, overlay: overlay);
      expect(find.text(DriverOfferTransferStrings.lastHint), findsOneWidget);
      await tester.ensureVisible(find.byType(DriverTransferOrderButton));
      await tester.tap(find.byType(DriverTransferOrderButton));
      await tester.pumpAndSettle();
      expect(find.text(DriverOfferTransferStrings.lastTitle), findsOneWidget);
      expect(
        find.text(DriverOfferTransferStrings.lastDescription),
        findsOneWidget,
      );
      await tester.tap(find.text(DriverOfferTransferStrings.goBack));
      await tester.pumpAndSettle();
      expect(fixture.orders.calls, 0);
      expect(fixture.count, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fourth transfer refreshes server lock; overlay=$overlay', (
      tester,
    ) async {
      final fixture = _Fixture(count: 3);
      await fixture.mount(tester, overlay: overlay);
      await _confirm(tester);
      expect(fixture.orders.calls, 1);
      expect(fixture.reads, greaterThan(0));
      expect(fixture.count, 0);
      expect(
        find.text(DriverOfferTransferStrings.lockedMessage),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DriverTransferOrderButton>(
              find.byType(DriverTransferOrderButton),
            )
            .onTap,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'transfer failure keeps quota and allows retry; overlay=$overlay',
      (tester) async {
        final fixture = _Fixture(count: 2)
          ..orders.error = StateError('network');
        await fixture.mount(tester, overlay: overlay);
        await _confirm(tester);
        expect(fixture.orders.calls, 1);
        expect(fixture.count, 2);
        expect(
          find.text(DriverOfferTransferStrings.remaining(2)),
          findsOneWidget,
        );
        expect(
          tester
              .widget<DriverTransferOrderButton>(
                find.byType(DriverTransferOrderButton),
              )
              .onTap,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'local offer expiry while confirming does not call transfer RPC; overlay=$overlay',
      (tester) async {
        final fixture = _Fixture(count: 3);
        await fixture.mount(tester, overlay: overlay);
        await tester.ensureVisible(find.byType(DriverTransferOrderButton));
        await tester.tap(find.byType(DriverTransferOrderButton));
        await tester.pumpAndSettle();
        fixture.clock = fixture.clock.add(const Duration(seconds: 46));
        await tester.tap(
          find.byKey(const Key('confirm-driver-offer-transfer')),
        );
        await tester.pumpAndSettle();
        expect(fixture.orders.calls, 0);
        expect(fixture.count, 3);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'successful transfer survives realtime removal; overlay=$overlay',
      (tester) async {
        final result = Completer<String?>();
        final fixture = _Fixture(count: 3)..orders.pending = result.future;
        await fixture.mount(tester, overlay: overlay);
        await _confirm(tester, settle: false);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: fixture.container,
            child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          ),
        );
        result.complete(null);
        await tester.pumpAndSettle();
        expect(fixture.orders.calls, 1);
        expect(fixture.reads, greaterThan(0));
        expect(fixture.lockedUntil, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed quota refresh does not report a committed transfer as failed',
    (tester) async {
      final fixture = _Fixture(count: 0)..failRefresh = true;
      await fixture.mount(tester, overlay: true);
      await _confirm(tester);
      expect(fixture.orders.calls, 1);
      expect(fixture.count, 1);
      expect(find.textContaining('Đã chuyển đơn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('last transfer sheet and lock card fit ${size.width}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final fixture = _Fixture(count: 3);
      await fixture.mount(tester, overlay: true, scale: 1.6);
      await tester.ensureVisible(find.byType(DriverTransferOrderButton));
      await tester.tap(find.byType(DriverTransferOrderButton));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('confirm-driver-offer-transfer'));
      await tester.ensureVisible(confirm);
      expect(tester.getRect(confirm).overlaps(Offset.zero & size), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.6),
              ),
              child: SingleChildScrollView(
                child: DriverAcceptanceLockCard(
                  lockedUntil: fixture.clock.add(const Duration(minutes: 30)),
                  now: () => fixture.clock,
                  onExpired: () {},
                  description: DriverOfferTransferStrings.lockDescription,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(DriverOfferTransferStrings.lockDescription),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _confirm(WidgetTester tester, {bool settle = true}) async {
  await tester.ensureVisible(find.byType(DriverTransferOrderButton));
  await tester.tap(find.byType(DriverTransferOrderButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm-driver-offer-transfer')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

class _Fixture {
  _Fixture({required this.count}) {
    orders.onCommitted = () {
      count++;
      if (count >= DriverOfferTransferState.limit) {
        lockedUntil = clock.add(DriverOfferTransferState.lockDuration);
        count = 0;
      }
    };
    container = ProviderContainer(
      overrides: [
        driverOrderRouteDistanceProvider.overrideWith(
          (ref, request) async =>
              const OrderRouteDistance(pickupMeters: 500, deliveryMeters: 3500),
        ),
        customerOrderServiceProvider.overrideWithValue(orders),
        driverAcceptanceStateProvider.overrideWith(
          (ref, id) => Stream.value(state),
        ),
        driverWalletSummaryProvider.overrideWith(
          (ref) async => const DriverWalletSummary(
            availableBalance: 100000,
            heldBalance: 0,
            todayIncome: 0,
          ),
        ),
        driverCancellationRepositoryProvider.overrideWithValue(
          DriverCancellationRepository(
            invoke: (name, params) async {
              reads++;
              if (failRefresh) throw StateError('snapshot unavailable');
              return {
                'server_now': clock.toIso8601String(),
                'locked_until': lockedUntil?.toIso8601String(),
                'lock_reason': lockedUntil != null ? 'offer_transfers' : null,
                'transfer_count': count,
              };
            },
          ),
        ),
      ],
    );
  }

  int count;
  int reads = 0;
  bool failRefresh = false;
  DateTime clock = DateTime.now().toUtc();
  DateTime? lockedUntil;
  final orders = _Orders();
  late final ProviderContainer container;

  DriverAcceptanceState get state => _ClockState(
    now: () => clock,
    lockedUntil: lockedUntil,
    transfers: DriverOfferTransferState(count: count),
    lockReason: lockedUntil != null ? 'offer_transfers' : null,
  );

  Future<void> mount(
    WidgetTester tester, {
    required bool overlay,
    double scale = 1,
  }) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    final order = OrderModel(
      id: 'offer',
      customerId: 'customer',
      status: 'confirmed',
      pickupAddress: 'Điểm lấy hàng',
      pickupLat: 10.77,
      pickupLng: 106.70,
      deliveryAddress: 'Điểm giao hàng',
      deliveryLat: 10.78,
      deliveryLng: 106.71,
      trackingCode: 'GH-TRANSFER',
      deliveryFee: 30000,
      paymentMethod: 'cash',
      serviceType: 'standard',
      createdAt: clock,
      updatedAt: clock,
      offeredDriverId: 'driver',
      offerExpiresAt: clock.add(const Duration(seconds: 45)),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: overlay
                  ? DriverIncomingOfferOverlay(
                      order: order,
                      driverUserId: 'driver',
                    )
                  : Scaffold(
                      body: SingleChildScrollView(
                        child: DriverOrderCard(
                          order: order,
                          acceptDriverId: 'driver',
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
}

class _ClockState extends DriverAcceptanceState {
  _ClockState({
    required DateTime Function() now,
    super.lockedUntil,
    super.transfers,
    super.lockReason,
  }) : _now = now,
       super(serverNow: now());
  final DateTime Function() _now;
  @override
  DateTime now() => _now();
}

class _Orders implements CustomerOrderService {
  int calls = 0;
  Object? error;
  Future<String?>? pending;
  late void Function() onCommitted;
  @override
  Future<String?> transferOrder(String orderId, String driverUserId) async {
    calls++;
    if (error != null) throw error!;
    final result = await (pending ?? Future.value('next-driver'));
    onCommitted();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
