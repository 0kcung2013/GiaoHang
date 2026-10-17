import 'dart:io';
import 'dart:ui' as ui;

import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/utils/delivery_eta_calculator.dart';
import 'package:giaohang_mobile/features/delivery_eta/models/order_eta.dart';
import 'package:giaohang_mobile/features/delivery_eta/order_eta_providers.dart';
import 'package:giaohang_mobile/features/delivery_eta/order_eta_strings.dart';
import 'package:giaohang_mobile/features/delivery_eta/utils/driver_departure_detector.dart';
import 'package:giaohang_mobile/features/delivery_eta/widgets/order_eta_panel.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  final now = DateTime.utc(2026, 10, 10, 10);
  OrderModel order({String status = 'assigned', String? driver = 'driver-1'}) =>
      OrderModel.fromJson({
        'id': 'order-eta-1',
        'customer_id': 'customer-1',
        'driver_id': driver,
        'status': status,
        'pickup_lat': 10.78,
        'pickup_lng': 106.68,
        'delivery_lat': 10.80,
        'delivery_lng': 106.71,
        'estimated_delivery_at': now
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
      });
  OrderEta eta({
    String? issue,
    double minutes = 29.4,
    bool preparationRemoved = false,
    bool synthetic = false,
  }) => OrderEta(
    observedAt: DateTime.now(),
    serverNow: now,
    issue: issue,
    data: {
      'driver_id': 'driver-1',
      'phase': 'fixed',
      'is_synthetic': synthetic,
      'calculation_mode': OrderEta.fixedCalculationMode,
      'computed_at': now.toIso8601String(),
      'predicted_at': now
          .add(
            Duration(
              milliseconds: (minutes * Duration.millisecondsPerMinute).round(),
            ),
          )
          .toIso8601String(),
      'preparation_minutes': preparationRemoved ? 0 : 5,
      'preparation_removed_minutes': preparationRemoved ? 5 : 0,
      'pickup_minutes': 5,
      'handoff_minutes': 5,
      'approach': {'travel_minutes': 2.4, 'used_ai': true},
      'delivery': {'travel_minutes': 12, 'used_ai': true},
    },
  );
  Future<void> pumpPanel(
    WidgetTester tester,
    OrderModel o, {
    OrderEta? value,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderEtaProvider(
            o.id,
          ).overrideWith((ref) => Stream.value(value ?? eta())),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(child: OrderEtaPanel(order: o)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'segment ETA shows simulation source and a separate LightGBM comparison',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final value = eta(synthetic: true);
      value.data!['approach'] = {
        'travel_minutes': 2.4,
        'used_ai': false,
        'lightgbm_travel_minutes': 3.2,
      };
      value.data!['delivery'] = {
        'travel_minutes': 12,
        'used_ai': false,
        'lightgbm_travel_minutes': 13.5,
      };
      expect(value.lightgbmComparisonMinutes, closeTo(16.7, 1e-8));
      await pumpPanel(tester, order(), value: value, scale: 1.6);
      await tester.tap(find.text(OrderEtaStrings.details));
      await tester.pumpAndSettle();
      expect(find.text(OrderEtaStrings.legacySimulated), findsOneWidget);
      expect(find.text(OrderEtaStrings.lightgbmComparison), findsOneWidget);
      expect(find.text(OrderEtaStrings.baseline), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('trained segment ETA shows AI as the primary source', (
    tester,
  ) async {
    final value = eta(synthetic: true);
    expect(value.usesAi, isTrue);
    expect(value.lightgbmComparisonMinutes, isNull);
    value.data!['approach']['distance_meters'] = 1000;
    value.data!['delivery']['distance_meters'] = 5000;
    await pumpPanel(tester, order(), value: value);
    await tester.tap(find.text(OrderEtaStrings.details));
    await tester.pumpAndSettle();
    expect(find.text(OrderEtaStrings.simulated), findsOneWidget);
    expect(find.text(OrderEtaStrings.lightgbmComparison), findsNothing);
    expect(find.text(OrderEtaStrings.distanceLabel), findsOneWidget);
    expect(find.text('6,00 km'), findsOneWidget);
    expect(find.text('25,0 km/h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('countdown uses server time, independent of a skewed device clock', () {
    final observed = now.add(const Duration(hours: 3));
    final value = OrderEta(
      data: {
        'computed_at': now.toIso8601String(),
        'predicted_at': now.add(const Duration(minutes: 10)).toIso8601String(),
      },
      serverNow: now,
      observedAt: observed,
    );
    expect(value.remainingAt(observed), 10);
    expect(value.remainingAt(observed.add(const Duration(minutes: 3))), 7);
    expect(value.remainingAt(observed.add(const Duration(minutes: 11))), 0);
    expect(value.staleAt(observed.add(const Duration(minutes: 3))), isTrue);
  });
  test(
    'OSRM low-speed boundary cannot make identical distance jump in ETA',
    () {
      final a = DeliveryEtaCalculator.calculate(
        distanceMeters: 1000,
        routeDurationSeconds: 720,
      );
      final b = DeliveryEtaCalculator.calculate(
        distanceMeters: 1000,
        routeDurationSeconds: 732,
      );
      expect(a.baselineTravelMinutes, closeTo(2.4, 1e-9));
      expect(a.minMinutes, b.minMinutes);
      expect(a.maxMinutes, b.maxMinutes);
      expect(a.rawRouteMinutes, isNot(b.rawRouteMinutes));
    },
  );
  test('a fixed forecast remains valid while its countdown advances', () {
    final observed = DateTime.now();
    final value = OrderEta(
      data: {
        'calculation_mode': OrderEta.fixedCalculationMode,
        'computed_at': now.toIso8601String(),
        'predicted_at': now.add(const Duration(minutes: 24)).toIso8601String(),
      },
      serverNow: now,
      observedAt: observed,
    );
    expect(value.remainingAt(observed.add(const Duration(minutes: 10))), 14);
    expect(value.staleAt(observed.add(const Duration(minutes: 10))), isFalse);
    expect(value.predictedAt, now.add(const Duration(minutes: 24)));
  });
  test('departure handles short simulation ticks', () {
    final detector = DriverDepartureDetector();
    for (var i = 0; i <= 20; i++) {
      detector.add(
        LatLng(10.78 + i * 0.000035, 106.68),
        now.add(Duration(milliseconds: i * 250)),
      );
    }
    expect(detector.departed, isTrue);
  });
  test(
    'GPS drift, inaccurate or stale fixes and teleportation do not end preparation',
    () {
      final detector = DriverDepartureDetector();
      for (var i = 0; i < 5; i++) {
        detector.add(
          LatLng(10.78 + i * 0.00001, 106.68),
          now.add(Duration(seconds: i * 5)),
        );
      }
      expect(detector.departed, isFalse);
      detector.add(
        const LatLng(10.8, 106.7),
        now.add(const Duration(seconds: 30)),
      );
      expect(detector.departed, isFalse);
      detector.add(
        const LatLng(10.8001, 106.7),
        now.add(const Duration(seconds: 35)),
        accuracyMeters: 100,
      );
      detector.add(
        const LatLng(10.8002, 106.7),
        now,
        now: now.add(const Duration(minutes: 2)),
      );
      expect(detector.departed, isFalse);
    },
  );
  test('real GPS confirms departure after three consistent fixes', () {
    final detector = DriverDepartureDetector();
    for (var i = 0; i < 4; i++) {
      detector.add(
        LatLng(10.78 + i * 0.00012, 106.68),
        now.add(Duration(seconds: i * 5)),
        accuracyMeters: 10,
      );
    }
    expect(detector.departed, isTrue);
  });
  testWidgets('pending order hides ETA despite an existing deadline', (
    tester,
  ) async {
    await pumpPanel(tester, order(status: 'pending', driver: null));
    expect(find.text(OrderEtaStrings.waiting), findsOneWidget);
    expect(find.text('16:00'), findsNothing);
    expect(find.text('17:29'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('the same server ETA stays visible in driver details and map', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final o = order();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderEtaProvider(o.id).overrideWith((ref) => Stream.value(eta())),
        ],
        child: MaterialApp(
          home: DriverNavigationView(
            order: o,
            currentUserId: 'driver-1',
            showOrderDetails: true,
            map: const SizedBox.expand(),
            arrivedAtTarget: false,
            isUpdatingStatus: false,
            onBack: () {},
            onFitMap: () {},
            onPrimaryAction: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('17:29').hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('driver-open-map')));
    await tester.pumpAndSettle();
    expect(find.text('17:29').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final config in [
    (const Size(320, 600), 1.6),
    (const Size(390, 760), 1.0),
    (const Size(1024, 768), 1.0),
  ]) {
    testWidgets(
      'server ETA and breakdown render at ${config.$1} / ${config.$2}',
      (tester) async {
        await tester.binding.setSurfaceSize(config.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpPanel(
          tester,
          order(),
          scale: config.$2,
          value: eta(synthetic: true),
        );
        expect(find.text('17:29'), findsOneWidget);
        expect(find.text(OrderEtaStrings.remaining(30)), findsOneWidget);
        await tester.tap(find.text(OrderEtaStrings.details));
        await tester.pump();
        expect(find.text(OrderEtaStrings.prepare), findsOneWidget);
        expect(find.text(OrderEtaStrings.approach), findsOneWidget);
        expect(find.text(OrderEtaStrings.simulated), findsOneWidget);
        expect(find.text(OrderEtaStrings.historical), findsNothing);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('ETA_VISUAL_QA')) {
          await _capture(tester, 'eta-${config.$1.width.toInt()}');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('stale route keeps last ETA with an explicit label', (
    tester,
  ) async {
    await pumpPanel(tester, order(), value: eta(issue: 'ETA_ROAD_UNAVAILABLE'));
    expect(find.text('17:29'), findsOneWidget);
    expect(find.text(OrderEtaStrings.stale), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('expired prediction is delayed, never Sắp đến', (tester) async {
    await pumpPanel(tester, order(), value: eta(minutes: -1));
    expect(find.text(OrderEtaStrings.delayed), findsOneWidget);
    expect(find.text('Sắp đến'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('terminal orders remove the ETA surface', (tester) async {
    for (final status in ['delivered', 'cancelled', 'returning']) {
      await pumpPanel(tester, order(status: status, driver: null));
      expect(find.byKey(const ValueKey('order-eta-panel')), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('estimate from a previous assignment is hidden', (tester) async {
    await pumpPanel(tester, order(driver: 'driver-2'), value: eta());
    expect(find.text('17:29'), findsNothing);
    expect(find.text(OrderEtaStrings.calculating), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'pickup and delivery keep the same forecast and initial details',
    (tester) async {
      for (final status in ['assigned', 'picking_up', 'delivering']) {
        await pumpPanel(tester, order(status: status), value: eta());
        expect(find.text('17:29'), findsOneWidget);
        await tester.tap(find.text(OrderEtaStrings.details));
        await tester.pump();
        expect(find.text(OrderEtaStrings.initialEstimate), findsOneWidget);
        expect(find.text(OrderEtaStrings.prepare), findsOneWidget);
        expect(find.text(OrderEtaStrings.approach), findsOneWidget);
        expect(find.text(OrderEtaStrings.pickupHandling), findsOneWidget);
        expect(find.text(OrderEtaStrings.deliveryHandling), findsOneWidget);
        expect(find.text(OrderEtaStrings.minutes(5)), findsNWidgets(3));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'early departure removes only five minutes and preserves travel and handling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPanel(
        tester,
        order(),
        value: eta(minutes: 24.4, preparationRemoved: true),
        scale: 1.6,
      );
      expect(find.text('17:24'), findsOneWidget);
      await tester.tap(find.text(OrderEtaStrings.details));
      await tester.pump();
      expect(find.text(OrderEtaStrings.prepare), findsNothing);
      expect(find.text(OrderEtaStrings.preparationRemoved), findsOneWidget);
      expect(find.text(OrderEtaStrings.approach), findsOneWidget);
      expect(find.text(OrderEtaStrings.pickupHandling), findsOneWidget);
      expect(find.text(OrderEtaStrings.deliveryHandling), findsOneWidget);
      expect(find.text(OrderEtaStrings.minutes(5)), findsNWidgets(2));
      if (const bool.fromEnvironment('ETA_VISUAL_QA')) {
        await _capture(tester, 'eta-preparation-removed');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  // Fonts are supplied by the test environment; pendingFonts can wait forever
  // with runtime fetching disabled. Pump the rendered frame instead.
  await tester.pumpAndSettle();
  final element = tester.element(find.byType(OrderEtaPanel));
  RenderObject? object = element.findRenderObject();
  while (object != null && object is! RenderRepaintBoundary) {
    object = object.parent;
  }
  final boundary = object! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final picture = await boundary
        .toImage(pixelRatio: 1)
        .timeout(const Duration(seconds: 15));
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('../../.tmp/eta-visual');
    await folder.create(recursive: true);
    await File(
      '${folder.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}
