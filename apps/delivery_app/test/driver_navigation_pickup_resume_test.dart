import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/driver_nav_session_provider.dart';
import 'package:delivery_app/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_delivery_workflow.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final scenario in [
    (status: 'delivering', savedStatus: null, pickedUp: true),
    (status: 'delivering', savedStatus: 'picking_up', pickedUp: true),
    (status: 'delivering', savedStatus: 'delivering', pickedUp: true),
    (status: 'delivering', savedStatus: 'delivering', pickedUp: false),
    (status: 'picking_up', savedStatus: null, pickedUp: true),
    (status: 'picking_up', savedStatus: 'picking_up', pickedUp: false),
  ]) {
    testWidgets(
      'reopening ${scenario.status} with ${scenario.savedStatus} session '
      'and pickedUp=${scenario.pickedUp} uses the current leg',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final sessions = DriverNavSessionsNotifier();
        await sessions.hydrate();
        if (scenario.savedStatus != null) {
          await sessions.upsert(
            DriverNavSession(
              orderId: 'order-resume',
              status: scenario.savedStatus!,
              lat: 10.773,
              lng: 106.703,
              pickupConfirmed: true,
            ),
          );
        }

        final container = ProviderContainer(
          overrides: [
            driverNavSessionsProvider.overrideWith((ref) => sessions),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: DriverNavigationScreen(
                order: _order(scenario.status, pickedUp: scenario.pickedUp),
              ),
            ),
          ),
        );

        final view = tester.widget<DriverNavigationView>(
          find.byType(DriverNavigationView),
        );
        final canMove = DriverDeliveryWorkflow.canSimulateMovement(
          status: view.order.status,
          pickupConfirmed: view.pickupConfirmed,
          arrivedAtTarget: view.arrivedAtTarget,
        );
        final waitingToStart = scenario.status == 'picking_up';
        expect(
          find.text('Chờ bắt đầu giao'),
          waitingToStart ? findsOneWidget : findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));

        expect(view.pickupConfirmed, waitingToStart);
        expect(canMove, !waitingToStart);
      },
    );
  }
}

OrderModel _order(String status, {bool pickedUp = true}) {
  final now = DateTime.utc(2026, 10, 3, 10);
  return OrderModel(
    id: 'order-resume',
    customerId: 'customer',
    status: status,
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.773,
    pickupLng: 106.703,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.776,
    deliveryLng: 106.701,
    createdAt: now,
    updatedAt: now,
    trackingCode: 'GH-10179',
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    actualPickedUpAt: pickedUp ? now : null,
    estimatedDeliveryAt: now.add(const Duration(minutes: 25)),
  );
}
