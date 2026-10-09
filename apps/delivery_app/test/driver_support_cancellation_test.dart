import 'dart:async';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/providers/driver_nav_session_provider.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/features/driver/cancellation/dialogs/driver_support_cancellation_dialog.dart';
import 'package:delivery_app/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:delivery_app/features/risk_reports/data/risk_intervention_repository.dart';
import 'package:delivery_app/features/risk_reports/widgets/driver_risk_instruction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'released pre-pickup order goes home and clears saved navigation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final sessions = DriverNavSessionsNotifier();
      await sessions.hydrate();
      final repository = _Repository();
      addTearDown(repository.dispose);
      final container = ProviderContainer(
        overrides: [
          driverNavSessionsProvider.overrideWith((ref) => sessions),
          driverByUserIdProvider('driver-1').overrideWith((ref) async => null),
          currentPositionProvider.overrideWith((ref) async => null),
          driverLocationModeProvider.overrideWith(
            (ref) => DriverLocationMode.demoHcm,
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/navigation',
        routes: [
          GoRoute(
            path: '/driver-home',
            builder: (_, _) => const Scaffold(body: Text('Trang chính')),
          ),
          GoRoute(
            path: '/navigation',
            builder: (_, _) => DriverNavigationScreen(
              order: _order(),
              riskInterventionRepository: repository,
            ),
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await sessions.upsert(
        DriverNavSession(
          orderId: 'order-1',
          status: 'picking_up',
          lat: 10.773,
          lng: 106.703,
          locationMode: DriverLocationMode.demoHcm,
        ),
      );
      repository.emit(
        _intervention(RiskInterventionState.heldBeforePickup, released: true),
      );
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Trang chính'), findsOneWidget);
      expect(find.text('Đơn đã được CSKH hủy'), findsOneWidget);
      expect(find.byType(DriverNavigationScreen), findsNothing);
      expect(find.text('Đã hoàn tất bàn giao'), findsNothing);
      expect(
        container.read(driverNavSessionsProvider).containsKey('order-1'),
        isFalse,
      );
      expect(container.read(activeDriverNavigationOrderProvider), isNull);
      expect(repository.custodyCalls, 0);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(find.text('Trang chính'), findsOneWidget);
      expect(find.text('Đơn đã được CSKH hủy'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (
      state: RiskInterventionState.heldBeforePickup,
      released: true,
      pickedUp: false,
      driver: 'driver-1',
      exits: true,
    ),
    (
      state: RiskInterventionState.handoffRequired,
      released: false,
      pickedUp: false,
      driver: 'driver-1',
      exits: false,
    ),
    (
      state: RiskInterventionState.heldBeforePickup,
      released: false,
      pickedUp: false,
      driver: 'driver-1',
      exits: false,
    ),
    (
      state: RiskInterventionState.heldBeforePickup,
      released: true,
      pickedUp: true,
      driver: 'driver-1',
      exits: false,
    ),
    (
      state: RiskInterventionState.heldBeforePickup,
      released: true,
      pickedUp: false,
      driver: 'other-driver',
      exits: false,
    ),
  ]) {
    testWidgets('release callback validates $scenario and runs once', (
      tester,
    ) async {
      final repository = _Repository();
      addTearDown(repository.dispose);
      var exits = 0;
      Widget build() => MaterialApp(
        home: Scaffold(
          body: DriverRiskInstructionRegion(
            order: _order(pickedUp: scenario.pickedUp),
            repository: repository,
            onDriverReleased: () async {
              exits++;
            },
            builder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpWidget(build());
      final intervention = _intervention(
        scenario.state,
        released: scenario.released,
        driver: scenario.driver,
      );
      repository.emit(intervention);
      await tester.pump();
      await tester.pump();
      if (scenario.state == RiskInterventionState.handoffRequired) {
        expect(find.text('CSKH yêu cầu bàn giao hàng'), findsNothing);
        expect(find.text('Đã hoàn tất bàn giao'), findsNothing);
      }
      await tester.pumpWidget(build());
      repository.emit(intervention);
      await tester.pump();
      await tester.pump();
      expect(exits, scenario.exits ? 1 : 0);
      expect(repository.watchCalls, 1);
      expect(repository.custodyCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in [
    (size: const Size(375, 568), scale: 1.6),
    (size: const Size(1280, 850), scale: 1.0),
  ]) {
    testWidgets('support cancellation notice fits ${viewport.size}', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
            child: child!,
          ),
          home: const Scaffold(body: DriverSupportCancellationDialog()),
        ),
      );
      expect(find.text('Đơn đã được CSKH hủy'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

OrderModel _order({bool pickedUp = false}) => OrderModel(
  trackingCode: 'GH-TEST',
  deliveryFee: 18000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  id: 'order-1',
  customerId: 'customer-1',
  driverId: 'driver-1',
  status: 'picking_up',
  pickupAddress: 'Điểm lấy',
  pickupLat: 10.773,
  pickupLng: 106.703,
  deliveryAddress: 'Điểm giao',
  deliveryLat: 10.776,
  deliveryLng: 106.701,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  actualPickedUpAt: pickedUp ? DateTime(2026) : null,
  estimatedDeliveryAt: DateTime(2026).add(const Duration(minutes: 25)),
);

RiskIntervention _intervention(
  RiskInterventionState state, {
  required bool released,
  String driver = 'driver-1',
}) => RiskIntervention(
  riskReportId: 'risk-1',
  orderId: 'order-1',
  state: state,
  driverId: driver,
  driverReleasedAt: released ? DateTime(2026) : null,
  instruction: null,
  decisionDueAt: DateTime(2026),
);

class _Repository implements RiskInterventionRepository {
  final _controller = StreamController<RiskIntervention?>.broadcast();
  var custodyCalls = 0;
  var watchCalls = 0;
  void emit(RiskIntervention value) => _controller.add(value);
  Future<void> dispose() => _controller.close();
  @override
  Future<RiskIntervention?> fetchForOrder(String orderId) async => null;
  @override
  Stream<RiskIntervention?> watchForOrder(String orderId) {
    watchCalls++;
    return _controller.stream;
  }

  @override
  Future<void> confirmCustodyResolved(String reportId, {String? note}) async {
    custodyCalls++;
  }
}
