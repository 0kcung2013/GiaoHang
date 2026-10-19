import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/features/driver/monitoring/driver_monitoring_providers.dart';
import 'package:giaohang_mobile/features/driver/monitoring/widgets/driver_monitoring_guard.dart';
import 'package:giaohang_mobile/features/driver/monitoring/widgets/driver_monitoring_panel.dart';
import 'package:giaohang_mobile/features/driver/screens/widgets/driver_active_delivery_location_tracker.dart';

final accepted = DateTime.utc(2026, 10, 19, 3, 57);

OrderModel order({DateTime? arrivedAt}) => OrderModel(
  id: 'order',
  customerId: 'customer',
  driverId: 'driver',
  status: 'picking_up',
  pickupAddress: 'Pickup',
  pickupLat: 11.033,
  pickupLng: 106.616,
  deliveryAddress: 'Delivery',
  deliveryLat: 11.035,
  deliveryLng: 106.619,
  createdAt: accepted,
  updatedAt: accepted,
  trackingCode: 'GH-test',
  deliveryFee: 0,
  serviceType: 'standard',
  paymentMethod: 'cash',
  pickupArrivedAt: arrivedAt,
);

// Reproduce the actual Shell call site: the order stream has confirmed arrival,
// while the independent monitoring RPC still reports no departure/arrival.
Future<StreamController<List<OrderModel>>> mountTracker(
  WidgetTester tester, {
  required int minute,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 568);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final orders = StreamController<List<OrderModel>>.broadcast();
  addTearDown(orders.close);
  final now = accepted.add(Duration(minutes: minute));
  final snapshot = DriverMonitoringSnapshot.fromJson({
    'status': 'picking_up',
    'released': false,
    'server_now': now.toIso8601String(),
    'state': DriverMonitoring(
      assignmentId: 'assignment',
      driverId: 'driver',
      acceptedAt: accepted,
      lastReceivedAt: now,
    ).toJson(),
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driverOrdersProvider('driver').overrideWith((ref) => orders.stream),
        driverByUserIdProvider('driver').overrideWith((ref) async => null),
        driverMonitoringProvider(
          'order',
        ).overrideWith((ref) => Stream.value(snapshot)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const Scaffold(
          body: DriverActiveDeliveryLocationTracker(userId: 'driver'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return orders;
}

void main() {
  testWidgets('confirmed pickup arrival prevents a stale departure reminder', (
    tester,
  ) async {
    final orders = await mountTracker(tester, minute: 5);
    orders.add([order(arrivedAt: accepted.add(const Duration(minutes: 3)))]);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(DriverMonitoringStrings.reminder), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'arrival closes an open warning before the next monitoring poll',
    (tester) async {
      final orders = await mountTracker(tester, minute: 8);
      orders.add([order()]);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text(DriverMonitoringStrings.warning), findsOneWidget);
      orders.add([order(arrivedAt: accepted.add(const Duration(minutes: 8)))]);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a driver who has not arrived still receives the reminder', (
    tester,
  ) async {
    final orders = await mountTracker(tester, minute: 5);
    orders.add([order()]);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(DriverMonitoringStrings.reminder), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an arrival from an older assignment does not hide a warning', (
    tester,
  ) async {
    final orders = await mountTracker(tester, minute: 8);
    orders.add([
      order(arrivedAt: accepted.subtract(const Duration(minutes: 1))),
    ]);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(DriverMonitoringStrings.warning), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final gpsMissing in [false, true]) {
    testWidgets(
      'arrival status card keeps GPS monitoring: missing=$gpsMissing',
      (tester) async {
        final now = accepted.add(const Duration(minutes: 8));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DriverMonitoringStatusCard(
                state: DriverMonitoring(
                  assignmentId: 'assignment',
                  driverId: 'driver',
                  acceptedAt: accepted,
                  lastReceivedAt: gpsMissing ? accepted : now,
                ),
                serverNow: now,
                holdingGoods: false,
                pickupArrivedAt: accepted.add(const Duration(minutes: 3)),
                onRecover: () async {},
              ),
            ),
          ),
        );
        expect(find.text(DriverMonitoringStrings.reminder), findsNothing);
        expect(find.text(DriverMonitoringStrings.warning), findsNothing);
        expect(
          find.text(
            gpsMissing
                ? DriverMonitoringStrings.gpsWarning
                : DriverMonitoringStrings.waitingPickup,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('confirmed arrival still handles a server monitoring release', (
    tester,
  ) async {
    var releases = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverMonitoringProvider('order').overrideWith(
            (ref) => Stream.value(
              DriverMonitoringSnapshot.fromJson({
                'released': true,
                'support_ticket_id': 'case',
                'server_now': accepted
                    .add(const Duration(minutes: 10))
                    .toIso8601String(),
              }),
            ),
          ),
        ],
        child: MaterialApp(
          home: DriverMonitoringGuard(
            orderId: 'order',
            pickupArrivedAt: accepted.add(const Duration(minutes: 3)),
            onReleased: (ticket) async {
              expect(ticket, 'case');
              releases++;
            },
            child: const Scaffold(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(releases, 1);
    expect(find.byType(Dialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
