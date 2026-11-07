import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show DriverMonitoring;
import 'package:giaohang_mobile/core/location/driver_arrival_fix.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/recipient_hold.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/driver_nav_session_provider.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:giaohang_mobile/features/driver/widgets/driver_swipe_action.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_navigation_arrival_bar.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/models/driver_delivery_arrival.dart';

const target = LatLng(10.79, 106.71);
OrderModel _order({DriverMonitoring? monitoring, String? driverId}) {
  final now = DateTime.now();
  return OrderModel(
    id: 'arrived-order',
    customerId: 'customer',
    driverId: driverId,
    driverMonitoring: monitoring,
    status: 'delivering',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.78,
    pickupLng: 106.70,
    deliveryAddress: 'Điểm giao',
    deliveryLat: target.latitude,
    deliveryLng: target.longitude,
    createdAt: now,
    updatedAt: now,
    trackingCode: 'GH-TEST',
    deliveryFee: 18000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    recipientHold: RecipientHold(
      until: now,
      startedAt: now.subtract(const Duration(minutes: 15)),
      state: 'resumed',
    ),
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  test('stationary simulation heartbeat cannot manufacture a real GPS fix', () {
    final now = DateTime.now();
    final real = DriverArrivalFix(
      position: target,
      capturedAt: now.subtract(const Duration(minutes: 2)),
      accuracy: 8,
      mode: DriverLocationMode.deviceGps,
    );
    expect(
      real.sampleStationarySimulation(
        current: target,
        currentMode: DriverLocationMode.deviceGps,
        now: now,
      ),
      isNull,
    );
    final simulated = DriverArrivalFix(
      position: target,
      capturedAt: now,
      accuracy: 0,
      mode: DriverLocationMode.demoCurrentPosition,
      simulated: true,
    );
    expect(
      simulated.sampleStationarySimulation(
        current: const LatLng(10.81, 106.73),
        currentMode: DriverLocationMode.demoCurrentPosition,
        now: now,
      ),
      isNull,
    );
    expect(
      simulated
          .sampleStationarySimulation(
            current: target,
            currentMode: DriverLocationMode.demoCurrentPosition,
            now: now.add(const Duration(minutes: 2)),
          )!
          .capturedAt,
      now.add(const Duration(minutes: 2)),
    );
  });
  test(
    'server monitoring restores capture data, never receipt/update time',
    () {
      final now = DateTime.now();
      final state = DriverMonitoring.fromJson({
        'assignment_id': 'assignment',
        'driver_id': 'driver',
        'accepted_at': now.toIso8601String(),
        'last_received_at': now.toIso8601String(),
        'last_captured_at': now
            .subtract(const Duration(seconds: 91))
            .toIso8601String(),
        'last_lat': target.latitude,
        'last_lng': target.longitude,
        'last_accuracy': 8,
      });
      final fix = DriverArrivalFix.fromMonitoring(
        state,
        driverId: 'driver',
        mode: DriverLocationMode.deviceGps,
      )!;
      expect(
        fix.canRestore(now: now, currentMode: DriverLocationMode.deviceGps),
        isFalse,
      );
      expect(
        DriverArrivalFix.fromMonitoring(
          state,
          driverId: 'another-driver',
          mode: DriverLocationMode.deviceGps,
        ),
        isNull,
      );
      expect(state!.toJson()['last_lat'], target.latitude);
    },
  );
  for (final scenario in [
    (
      name:
          'cold restart waits for a driver capture instead of using parcel GPS',
      position: target,
      age: 0,
      mode: DriverLocationMode.deviceGps,
      fixMode: DriverLocationMode.deviceGps,
      expected: false,
      savedArrived: false,
    ),
    (
      name: 'fresh simulation at destination',
      position: target,
      age: 0,
      mode: DriverLocationMode.demoCurrentPosition,
      fixMode: DriverLocationMode.demoCurrentPosition,
      expected: true,
      savedArrived: true,
    ),
    (
      name: 'previously erased arrival flag',
      position: target,
      age: 0,
      mode: DriverLocationMode.demoCurrentPosition,
      fixMode: DriverLocationMode.demoCurrentPosition,
      expected: true,
      savedArrived: false,
    ),
    (
      name: 'driver has moved to another delivery',
      position: const LatLng(10.81, 106.73),
      age: 0,
      mode: DriverLocationMode.demoCurrentPosition,
      fixMode: DriverLocationMode.demoCurrentPosition,
      expected: false,
      savedArrived: true,
    ),
    (
      name: 'stale fix',
      position: target,
      age: 91,
      mode: DriverLocationMode.demoCurrentPosition,
      fixMode: DriverLocationMode.demoCurrentPosition,
      expected: false,
      savedArrived: true,
    ),
    (
      name: 'location mode changed',
      position: target,
      age: 0,
      mode: DriverLocationMode.demoCurrentPosition,
      fixMode: DriverLocationMode.deviceGps,
      expected: false,
      savedArrived: true,
    ),
    (
      name: 'fresh device GPS at destination',
      position: target,
      age: 0,
      mode: DriverLocationMode.deviceGps,
      fixMode: DriverLocationMode.deviceGps,
      expected: true,
      savedArrived: true,
    ),
  ]) {
    testWidgets('tab reopen: ${scenario.name}', (tester) async {
      final cold = scenario.name.startsWith('cold restart');
      final activeOrder = _order(
        driverId: cold ? 'driver' : null,
        monitoring: cold
            ? DriverMonitoring(
                assignmentId: 'assignment',
                driverId: 'driver',
                acceptedAt: DateTime.now(),
                lastCapturedAt: DateTime.now(),
                lastLat: target.latitude,
                lastLng: target.longitude,
                lastAccuracy: 8,
              )
            : null,
      );
      final sessions = DriverNavSessionsNotifier();
      await sessions.hydrate();
      await sessions.upsert(
        DriverNavSession(
          orderId: 'arrived-order',
          status: 'delivering',
          lat: target.latitude,
          lng: target.longitude,
          arrivedAtTarget: scenario.savedArrived,
          routeCompleted: scenario.savedArrived,
          locationMode: scenario.mode,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          driverNavSessionsProvider.overrideWith((ref) => sessions),
          driverLocationModeProvider.overrideWith((ref) => scenario.mode),
          driverPhysicalPositionProvider.overrideWith(
            (ref) => scenario.position,
          ),
          driverArrivalFixProvider.overrideWith(
            (ref) => cold
                ? null
                : DriverArrivalFix(
                    position: scenario.position,
                    capturedAt: DateTime.now().subtract(
                      Duration(seconds: scenario.age),
                    ),
                    accuracy: 8,
                    mode: scenario.fixMode,
                  ),
          ),
          driverOrdersProvider(
            '',
          ).overrideWith((ref) => Stream.value([activeOrder])),
          driverOrdersProvider(
            'driver',
          ).overrideWith((ref) => Stream.value([activeOrder])),
        ],
      );
      final physical = container.listen(
        driverPhysicalPositionProvider,
        (_, _) {},
      );
      final fix = container.listen(driverArrivalFixProvider, (_, _) {});
      final arrivalStates = <bool>[];
      try {
        for (var i = 0; i < 3; i++) {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: DriverNavigationScreen(order: activeOrder),
              ),
            ),
          );
          final view = tester.widget<DriverNavigationView>(
            find.byType(DriverNavigationView),
          );
          arrivalStates.add(view.arrivedAtTarget);
          // Check the actual action after the server arrival snapshot loads.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DriverNavigationArrivalBar(
                  order: view.order,
                  arrivedAtTarget: view.arrivedAtTarget,
                  pickupConfirmed: false,
                  isLoading: false,
                  onPrimaryAction: () => {},
                  onConfirmDeliveryArrival: () => {},
                  deliveryArrival: DriverDeliveryArrival(
                    arrivedAt: DateTime.now(),
                    serverNow: DateTime.now(),
                    canReport: false,
                  ),
                ),
              ),
            ),
          );
          final swipe = tester.widget<DriverSwipeAction>(
            find.byType(DriverSwipeAction),
          );
          expect(swipe.onCompleted != null, scenario.expected);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 1));
        }
        expect(arrivalStates, everyElement(scenario.expected));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
        physical.close();
        fix.close();
        container.dispose();
        await tester.pump(const Duration(milliseconds: 1));
      }
    });
  }
}
