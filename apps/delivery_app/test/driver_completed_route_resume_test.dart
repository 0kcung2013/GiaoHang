import 'dart:convert';

import 'package:delivery_app/core/providers/driver_nav_session_provider.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_delivery_workflow.dart';
import 'package:delivery_app/features/driver/screens/navigation/utils/driver_demo_movement_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scenario in [
    (
      savedStatus: 'delivering',
      mode: DriverLocationMode.demoHcm,
      stopped: true,
    ),
    (
      savedStatus: 'picking_up',
      mode: DriverLocationMode.demoHcm,
      stopped: false,
    ),
    (
      savedStatus: 'delivering',
      mode: DriverLocationMode.deviceGps,
      stopped: false,
    ),
  ]) {
    testWidgets(
      'restores ${scenario.savedStatus} in ${scenario.mode.name} on the current leg',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final sessions = DriverNavSessionsNotifier();
        await sessions.hydrate();
        await sessions.upsert(
          DriverNavSession(
            orderId: 'completed',
            status: scenario.savedStatus,
            lat: 10.776,
            lng: 106.701,
            arrivedAtTarget: true,
            routeCompleted: true,
            locationMode: scenario.mode,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            driverNavSessionsProvider.overrideWith((ref) => sessions),
            driverLocationModeProvider.overrideWith((ref) => scenario.mode),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: DriverNavigationScreen(order: _order())),
          ),
        );
        final view = tester.widget<DriverNavigationView>(
          find.byType(DriverNavigationView),
        );
        expect(view.routeCompleted, scenario.stopped);
        expect(view.arrivedAtTarget, scenario.savedStatus == 'delivering');
        expect(
          find.text('GPS mô phỏng đã dừng'),
          scenario.stopped ? findsOneWidget : findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final viewport in [
    (size: const Size(375, 568), scale: 1.6),
    (size: const Size(882, 849), scale: 1.0),
  ]) {
    testWidgets(
      'completed header ignores stale routing metrics at ${viewport.size}',
      (tester) async {
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
            home: DriverNavigationView(
              order: _order(),
              map: const SizedBox.expand(),
              arrivedAtTarget: true,
              routeCompleted: true,
              isUpdatingStatus: false,
              onBack: () {},
              onFitMap: () {},
              onPrimaryAction: () {},
              totalDistance: 652,
              maneuverDistance: 652,
              totalDuration: 180,
            ),
          ),
        );
        expect(find.text('Đã đến điểm giao'), findsOneWidget);
        expect(find.text('GPS mô phỏng đã dừng'), findsOneWidget);
        expect(find.textContaining('652'), findsNothing);
        expect(find.text('3 phút'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final legacy in [false, true]) {
    test(
      'reload does not restart a completed ${legacy ? 'legacy' : 'current'} route',
      () async {
        final saved = {
          'orderId': 'completed',
          'status': 'delivering',
          'lat': 10.776,
          'lng': 106.701,
          'arrivedAtTarget': true,
          'simRouteIndex': 42,
          if (!legacy) 'routeCompleted': true,
        };
        SharedPreferences.setMockInitialValues({
          'driver_nav_sessions_v1': jsonEncode({'completed': saved}),
        });
        final sessions = DriverNavSessionsNotifier();
        addTearDown(sessions.dispose);
        await sessions.hydrate();
        final restored = sessions.state['completed']!;
        final tracker = DriverDemoMovementTracker(
          interval: const Duration(milliseconds: 1),
        );
        addTearDown(tracker.dispose);
        var published = 0;
        // A refreshed route can go around a one-way street even at the destination.
        tracker.start(
          route: const [
            LatLng(10.776, 106.701),
            LatLng(10.78, 106.705),
            LatLng(10.776, 106.701),
          ],
          currentPosition: LatLng(restored.lat, restored.lng),
          nextRouteIndex: 1,
          canMove: () => DriverDeliveryWorkflow.canSimulateMovement(
            status: restored.status,
            pickupConfirmed: restored.pickupConfirmed,
            arrivedAtTarget: restored.arrivedAtTarget,
            routeCompleted: restored.routeCompleted,
          ),
          onPosition: (_, _, _) => published++,
        );
        expect(tracker.isRunning, isFalse);
        expect(published, 0);
        expect(restored.routeCompleted, isTrue);
      },
    );
  }

  test(
    'a new session inside the arrival radius can still finish its route',
    () async {
      SharedPreferences.setMockInitialValues({});
      final firstRun = DriverNavSessionsNotifier();
      await firstRun.hydrate();
      await firstRun.upsert(
        const DriverNavSession(
          orderId: 'nearby',
          status: 'delivering',
          lat: 10.776,
          lng: 106.701,
          arrivedAtTarget: true,
          routeCompleted: false,
        ),
      );
      firstRun.dispose();
      final secondRun = DriverNavSessionsNotifier();
      addTearDown(secondRun.dispose);
      await secondRun.hydrate();
      final restored = secondRun.state['nearby']!;
      expect(restored.routeCompleted, isFalse);
      expect(
        DriverDeliveryWorkflow.canSimulateMovement(
          status: restored.status,
          pickupConfirmed: false,
          arrivedAtTarget: restored.arrivedAtTarget,
          routeCompleted: restored.routeCompleted,
        ),
        isTrue,
      );
    },
  );
}

OrderModel _order() {
  final now = DateTime.utc(2026, 10, 8);
  return OrderModel(
    id: 'completed',
    customerId: 'customer',
    status: 'delivering',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.773,
    pickupLng: 106.703,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.776,
    deliveryLng: 106.701,
    createdAt: now,
    updatedAt: now,
    trackingCode: 'GH-10180',
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
  );
}
