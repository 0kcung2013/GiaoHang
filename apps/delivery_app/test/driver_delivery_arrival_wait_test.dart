import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/data/driver_delivery_arrival_repository.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_delivery_arrival.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_arrival_bar.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_delivery_arrival_region.dart';
import 'package:delivery_app/features/driver/screens/navigation/utils/driver_delivery_arrival_strings.dart';
import 'package:delivery_app/features/driver/widgets/driver_swipe_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _now = DateTime.utc(2026, 10, 3, 12);
OrderModel get _order => OrderModel(
  id: 'order',
  customerId: 'customer',
  driverId: 'driver',
  status: 'delivering',
  pickupAddress: 'Điểm lấy',
  pickupLat: 10,
  pickupLng: 106,
  deliveryAddress: 'Điểm giao',
  deliveryLat: 10.01,
  deliveryLng: 106.01,
  createdAt: _now,
  updatedAt: _now,
  trackingCode: 'GH-1',
  deliveryFee: 20000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  estimatedDeliveryAt: _now.add(const Duration(minutes: 20)),
);

void main() {
  testWidgets(
    'retry repeats GPS preparation and confirmation, then starts wait',
    (tester) async {
      var preparations = 0;
      var confirmations = 0;
      final repository = DriverDeliveryArrivalRepository(
        invoke: (name, _) async {
          if (name == 'confirm_driver_delivery_arrival') {
            confirmations++;
            if (confirmations == 1) {
              throw const PostgrestException(
                message: 'DELIVERY_LOCATION_STALE',
                code: '23514',
              );
            }
          }
          return {
            'delivery_arrived_at': confirmations > 1
                ? _now.toIso8601String()
                : null,
            'server_now': _now.toIso8601String(),
            'can_report_recipient': false,
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverDeliveryArrivalRegion(
              orderId: 'order',
              repository: repository,
              beforeConfirm: () async {
                preparations++;
              },
              builder: (arrival, elapsed, loading, error, confirm, retry) =>
                  DriverNavigationArrivalBar(
                    order: _order,
                    arrivedAtTarget: true,
                    pickupConfirmed: true,
                    isLoading: loading,
                    onPrimaryAction: () {},
                    deliveryArrival: arrival,
                    deliveryWait: elapsed,
                    onConfirmDeliveryArrival: confirm,
                    arrivalError: error,
                    onRetryArrival: retry,
                  ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.drag(find.byType(DriverSwipeAction), const Offset(600, 0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(confirmations, 1);
      expect(
        find.text(DriverDeliveryArrivalStrings.locationStale),
        findsOneWidget,
      );
      final retryAction = find.byWidgetPredicate(
        (widget) =>
            widget is TextButton &&
            widget.child is Text &&
            (widget.child! as Text).data !=
                DriverDeliveryArrivalStrings.deliverNow,
      );
      await tester.tap(retryAction);
      await tester.pump();
      expect(preparations, 2);
      expect(confirmations, 2);
      expect(find.text('Chờ 10:00 · Báo sự cố'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed snapshot stays closed, retry and resume restore server state',
    (tester) async {
      var fail = true;
      var reads = 0;
      final repository = DriverDeliveryArrivalRepository(
        invoke: (_, _) async {
          reads++;
          if (fail) throw StateError('network');
          return {
            'delivery_arrived_at': _now.toIso8601String(),
            'server_now': _now
                .add(const Duration(minutes: 10))
                .toIso8601String(),
            'can_report_recipient': true,
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DriverDeliveryArrivalRegion(
            orderId: 'order',
            repository: repository,
            builder: (arrival, elapsed, loading, error, confirm, retry) =>
                Column(
                  children: [
                    Text(
                      error ??
                          (arrival?.canReport == true ? 'ready' : 'locked'),
                    ),
                    TextButton(
                      onPressed: loading ? null : retry,
                      child: const Text('retry'),
                    ),
                  ],
                ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(DriverDeliveryArrivalStrings.retry), findsOneWidget);
      fail = false;
      await tester.tap(find.text('retry'));
      await tester.pump();
      expect(find.text('ready'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(reads, 3);
      expect(find.text('ready'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'arrival repository preserves server time and confirmation contract',
    () async {
      final names = <String>[];
      final repository = DriverDeliveryArrivalRepository(
        invoke: (name, params) async {
          names.add(name);
          expect(params, {'p_order_id': 'order'});
          return {
            'delivery_arrived_at': _now.toIso8601String(),
            'server_now': _now
                .add(const Duration(minutes: 10))
                .toIso8601String(),
            'can_report_recipient': true,
          };
        },
      );
      expect(
        (await repository.confirm('order')).elapsed,
        const Duration(minutes: 10),
      );
      expect((await repository.read('order')).canReport, isTrue);
      expect(names, [
        'confirm_driver_delivery_arrival',
        'get_driver_delivery_arrival',
      ]);
    },
  );

  testWidgets(
    'arrival swipe is separate from delivery and report needs server permission',
    (tester) async {
      var confirmed = 0;
      var reported = 0;
      var delivered = 0;
      Future<void> show(
        DriverDeliveryArrival arrival, {
        bool near = true,
        Duration? displayWait,
      }) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverNavigationArrivalBar(
              order: _order,
              arrivedAtTarget: near,
              pickupConfirmed: true,
              isLoading: false,
              onPrimaryAction: () => delivered++,
              onConfirmDeliveryArrival: () => confirmed++,
              onReportRecipient: () => reported++,
              deliveryArrival: arrival,
              deliveryWait: displayWait ?? arrival.elapsed,
            ),
          ),
        ),
      );
      final pending = DriverDeliveryArrival(
        arrivedAt: null,
        serverNow: _now,
        canReport: false,
      );
      await show(pending, near: false);
      expect(
        tester
            .widget<DriverSwipeAction>(find.byType(DriverSwipeAction))
            .onCompleted,
        isNull,
      );
      await show(pending);
      expect(
        find.text(DriverDeliveryArrivalStrings.swipeArrival),
        findsOneWidget,
      );
      await tester.drag(find.byType(DriverSwipeAction), const Offset(600, 0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(confirmed, 1);
      expect(delivered, 0);
      await tester.tap(find.text('Giao hàng ngay'));
      expect(delivered, 1);
      final waiting = DriverDeliveryArrival(
        arrivedAt: _now,
        serverNow: _now.add(const Duration(minutes: 9)),
        canReport: false,
      );
      await show(waiting, displayWait: const Duration(minutes: 11));
      expect(find.text('Gạt đã giao'), findsOneWidget);
      await tester.tap(find.byKey(const Key('driver-report-recipient-action')));
      expect(
        reported,
        0,
        reason: 'Local elapsed time cannot authorize a report',
      );
      await show(
        DriverDeliveryArrival(
          arrivedAt: _now,
          serverNow: _now.add(const Duration(minutes: 10)),
          canReport: true,
        ),
      );
      await tester.tap(find.text(DriverDeliveryArrivalStrings.reportRecipient));
      expect(reported, 1);
    },
  );

  testWidgets(
    'restores arrival from server and stays compact at mobile sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reads = 0;
      final repository = DriverDeliveryArrivalRepository(
        invoke: (_, _) async {
          reads++;
          return {
            'delivery_arrived_at': _now.toIso8601String(),
            'server_now': _now
                .add(const Duration(minutes: 3))
                .toIso8601String(),
            'can_report_recipient': false,
          };
        },
      );
      for (final size in [
        const Size(320, 568),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
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
                  key: UniqueKey(),
                  order: _order,
                  pickupConfirmed: true,
                  map: const ColoredBox(color: Colors.white),
                  arrivedAtTarget: true,
                  isUpdatingStatus: false,
                  onBack: () {},
                  onFitMap: () {},
                  onPrimaryAction: () {},
                  onContact: () {},
                  onPrepareDeliveryArrival: () async {},
                  onReportRecipient: () {},
                  deliveryArrivalRepository: repository,
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('Gạt đã giao'), findsOneWidget);
          expect(find.text('Đang giao hàng'), findsOneWidget);
          expect(find.text('Chờ bắt đầu giao'), findsNothing);
          final bar = tester.getRect(find.byType(DriverNavigationArrivalBar));
          expect(bar.bottom, lessThanOrEqualTo(size.height));
          if (size.height > 500) {
            expect(bar.height, lessThan(size.height * 0.4));
          }
        }
      }
      expect(reads, 6);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
