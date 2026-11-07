import 'helpers/utraffic_capture_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/core/location/driver_workload_policy.dart';
import 'package:giaohang_mobile/core/location/physical_gps_policy.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/recipient_hold.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/driver_task_priority_provider.dart';
import 'package:giaohang_mobile/features/driver/recipient_hold/driver_held_order_card.dart';
import 'package:giaohang_mobile/features/driver/recipient_hold/recipient_hold_repository.dart';
import 'package:giaohang_mobile/features/driver/recipient_hold/recipient_hold_strings.dart';
import 'package:giaohang_mobile/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:giaohang_mobile/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:giaohang_mobile/features/driver/recipient_hold/recipient_hold_sheet.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_priority_orders.dart';

final now = DateTime.utc(2026, 10, 29, 8);
OrderModel order(String id, {RecipientHold? hold}) => OrderModel(
  id: id,
  customerId: 'customer',
  driverId: 'driver',
  status: 'delivering',
  pickupAddress: '25 Nguyễn Trãi, Phường Bến Thành, TP.HCM',
  pickupLat: 10.78,
  pickupLng: 106.7,
  deliveryAddress: id == 'old'
      ? '12 Lê Lợi, Phường Bến Thành, TP.HCM'
      : '25 Nguyễn Trãi, Phường Bến Thành, TP.HCM',
  deliveryLat: 10.79,
  deliveryLng: 106.71,
  createdAt: now,
  updatedAt: now,
  trackingCode: id == 'old' ? 'GH001' : 'GH002',
  deliveryFee: 18000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  recipientHold: hold,
);

void main() {
  setUpAll(prepareUtrafficCaptureFonts);
  test(
    'physical position persists across task changes and is released with driver shell',
    () async {
      final container = ProviderContainer();
      final shell = container.listen(
        driverPhysicalPositionProvider.select((_) => null),
        (_, _) {},
      );
      container.read(driverPhysicalPositionProvider.notifier).state =
          const LatLng(10.81, 106.73);
      await container.pump();
      expect(
        container.read(driverPhysicalPositionProvider),
        const LatLng(10.81, 106.73),
      );
      shell.close();
      await container.pump();
      expect(container.read(driverPhysicalPositionProvider), isNull);
      container.dispose();
    },
  );
  final held = order(
    'old',
    hold: RecipientHold(
      startedAt: now,
      until: now.add(const Duration(minutes: 30)),
      state: 'holding',
    ),
  );
  final working = order('new');
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  test('GPS owner is working order even when held order comes first', () {
    expect(DriverWorkloadPolicy.locationOwner([held, working])?.id, 'new');
    expect(DriverWorkloadPolicy.locationOwner([working, held])?.id, 'new');
    expect(DriverWorkloadPolicy.locationOwner([held])?.id, 'old');
    expect(DriverWorkloadPolicy.locationOwner([]), isNull);
  });
  test(
    'switching between two active tasks keeps the same physical GPS',
    () async {
      final resumed = order(
        'old',
        hold: RecipientHold(
          startedAt: now,
          until: now.add(const Duration(minutes: 30)),
          state: 'resumed',
        ),
      );
      final changes = StreamController<List<OrderModel>>();
      final container = ProviderContainer(
        overrides: [
          driverOrdersProvider('driver').overrideWith((ref) => changes.stream),
          driverPhysicalPositionProvider.overrideWith(
            (ref) => const LatLng(10.81, 106.73),
          ),
        ],
      );
      final owner = container.listen(
        driverLocationOwnerProvider('driver'),
        (_, _) {},
      );
      final physical = container.listen(
        driverPhysicalPositionProvider,
        (_, _) {},
      );
      changes.add([working, resumed]);
      await container.pump();
      expect(owner.read()?.id, 'old');
      container.read(driverPriorityOrderIdProvider.notifier).state = 'new';
      await container.pump();
      expect(owner.read()?.id, 'new');
      container.read(activeDriverNavigationOrderProvider.notifier).state =
          'old';
      await container.pump();
      expect(owner.read()?.id, 'old');
      container.read(activeDriverNavigationOrderProvider.notifier).state = null;
      await container.pump();
      expect(owner.read()?.id, 'new');
      changes.add([resumed]);
      await container.pump();
      expect(
        owner.read()?.id,
        'old',
        reason:
            'Completed priority task must fall back to the remaining parcel',
      );
      expect(physical.read(), const LatLng(10.81, 106.73));
      expect(DriverWorkloadPolicy.canReceive([resumed, working], now), isFalse);
      owner.close();
      physical.close();
      container.dispose();
      await changes.close();
    },
  );
  test(
    'one hold frees capacity; working order or due hold blocks acceptance',
    () {
      expect(DriverWorkloadPolicy.canReceive([held], now), isTrue);
      expect(DriverWorkloadPolicy.canReceive([held, working], now), isFalse);
      expect(
        DriverWorkloadPolicy.canReceive([held], held.recipientHold!.until),
        isFalse,
      );
    },
  );
  test('device GPS and any hold history cannot restore a parcel position', () {
    expect(
      DriverWorkloadPolicy.canRestoreOrderPosition(
        deviceGps: true,
        hasHoldHistory: false,
      ),
      isFalse,
    );
    expect(
      DriverWorkloadPolicy.canRestoreOrderPosition(
        deviceGps: false,
        hasHoldHistory: true,
      ),
      isFalse,
    );
    expect(
      DriverWorkloadPolicy.canRestoreOrderPosition(
        deviceGps: false,
        hasHoldHistory: false,
      ),
      isTrue,
    );
  });
  test('GPS quality rejects old, future and inaccurate samples', () {
    expect(
      PhysicalGpsPolicy.accepts(now: now, capturedAt: now, accuracy: 8),
      isTrue,
    );
    expect(
      PhysicalGpsPolicy.accepts(
        now: now,
        capturedAt: now.subtract(const Duration(seconds: 91)),
        accuracy: 8,
      ),
      isFalse,
    );
    expect(
      PhysicalGpsPolicy.accepts(
        now: now,
        capturedAt: now.add(const Duration(seconds: 16)),
        accuracy: 8,
      ),
      isFalse,
    );
    expect(
      PhysicalGpsPolicy.accepts(now: now, capturedAt: now, accuracy: 51),
      isFalse,
    );
    expect(
      PhysicalGpsPolicy.accepts(
        now: now,
        capturedAt: now,
        accuracy: double.nan,
      ),
      isFalse,
    );
  });
  test(
    'backend hold snapshot retains deadline and request state across copyWith',
    () {
      final json = held.toJson();
      json['delivery_hold'] = {
        'state': 'holding',
        'started_at': now.toIso8601String(),
        'until': now.add(const Duration(minutes: 30)).toIso8601String(),
        'return_report_id': 'report',
      };
      final restored = OrderModel.fromJson(json);
      expect(restored.isRecipientHeld, isTrue);
      expect(
        restored.copyWith(status: 'delivering').recipientHold!.returnRequested,
        isTrue,
      );
      expect(
        restored.recipientHold!.returnEligibleAt,
        now.add(const Duration(minutes: 35)),
      );
    },
  );
  for (final redelivering in [false, true]) {
    for (final spec in [
      (320.0, 568.0, 1.0),
      (390.0, 844.0, 1.0),
      (320.0, 568.0, 1.6),
      (900.0, 700.0, 1.0),
    ]) {
      testWidgets(
        'two visible tasks fit ${spec.$1}dp text ${spec.$3} resumed $redelivering',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(spec.$1, spec.$2);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          final oldOrder = redelivering
              ? order(
                  'old',
                  hold: RecipientHold(
                    startedAt: now,
                    until: now.add(const Duration(minutes: 30)),
                    state: 'resumed',
                  ),
                )
              : held;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                driverOrdersProvider(
                  'driver',
                ).overrideWith((ref) => Stream.value([oldOrder, working])),
                driverAcceptanceStateProvider('driver').overrideWith(
                  (ref) => Stream.value(DriverAcceptanceState(serverNow: now)),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData(
                  fontFamily: AppTextStyles.bodyMedium.fontFamily,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(spec.$1, spec.$2),
                    textScaler: TextScaler.linear(spec.$3),
                  ),
                  child: Scaffold(
                    backgroundColor: const Color(0xFFFAFAFA),
                    body: RepaintBoundary(
                      key: boundary,
                      child: ColoredBox(
                        color: const Color(0xFFFAFAFA),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: DriverPriorityOrders(
                            availableOrders: const [],
                            driverOrders: [oldOrder, working],
                            driverUserId: 'driver',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          if (redelivering) {
            expect(find.text('Đang giao lại'), findsOneWidget);
            expect(find.text('Tiếp tục đơn hàng'), findsNWidgets(2));
            expect(find.text(RecipientHoldStrings.resume), findsNothing);
            expect(
              tester
                  .getTopLeft(find.byKey(const ValueKey('working-order-old')))
                  .dy,
              lessThan(
                tester
                    .getTopLeft(find.byKey(const ValueKey('working-order-new')))
                    .dy,
              ),
            );
          } else {
            expect(find.text('Đang giữ'), findsOneWidget);
            expect(find.text('Tiếp tục đơn hàng'), findsOneWidget);
            final resume = tester.widget<OutlinedButton>(
              find.byWidgetPredicate((widget) => widget is OutlinedButton),
            );
            expect(
              resume.onPressed,
              isNotNull,
              reason:
                  'A recipient may be ready early, even with another active order',
            );
          }
          expect(tester.takeException(), isNull);
          if (spec.$1 == 390) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                redelivering
                    ? '../../artifacts/driver_early_redelivery_390.png'
                    : '../../artifacts/driver_recipient_hold_390.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'resume before appointment calls server even with another order; busy prevents duplicates',
    (tester) async {
      final repo = _PendingResumeRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipientHoldRepositoryProvider.overrideWithValue(repo),
            driverOrdersProvider(
              'driver',
            ).overrideWith((ref) => Stream.value([held, working])),
            driverAcceptanceStateProvider('driver').overrideWith(
              (ref) => Stream.value(DriverAcceptanceState(serverNow: now)),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: DriverHeldOrderCard(order: held)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(RecipientHoldStrings.resume));
      await tester.pump();
      expect(repo.calls, 1);
      final resumeButton = find.byWidgetPredicate((w) => w is OutlinedButton);
      final button = tester.widget<OutlinedButton>(resumeButton);
      expect(button.onPressed, isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      repo.response.completeError(StateError('network unavailable'));
      await tester.pump();
      expect(find.text(RecipientHoldStrings.failed), findsOneWidget);
      expect(tester.widget<OutlinedButton>(resumeButton).onPressed, isNotNull);
      expect(held.isRecipientHeld, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('hold sheet custom duration and keyboard fit at 320dp', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showRecipientHoldSheet(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tùy chọn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '25');
    await tester.pump();
    await tester.ensureVisible(find.text('Xác nhận giữ đơn'));
    await tester.tap(find.text('Xác nhận giữ đơn'));
    await tester.pumpAndSettle();
    expect(selected, 25);
    expect(tester.takeException(), isNull);
  });
}

class _PendingResumeRepository extends RecipientHoldRepository {
  final response = Completer<OrderModel>();
  int calls = 0;
  @override
  Future<OrderModel> update(String orderId, {int? minutes}) {
    calls++;
    expect(orderId, 'old');
    expect(minutes, isNull);
    return response.future;
  }
}
