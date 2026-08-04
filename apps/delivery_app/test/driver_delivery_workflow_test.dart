import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_delivery_workflow.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_delivery_workflow_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverDeliveryWorkflow', () {
    test('maps the active order statuses to four explicit stages', () {
      final assigned = DriverDeliveryWorkflow.fromStatus('assigned');
      final pickup = DriverDeliveryWorkflow.fromStatus('picking_up');
      final awaitingDeliveryStart = DriverDeliveryWorkflow.fromStatus(
        'picking_up',
        pickupConfirmed: true,
      );
      final delivery = DriverDeliveryWorkflow.fromStatus('delivering');
      final delivered = DriverDeliveryWorkflow.fromStatus('delivered');

      expect(assigned.stepIndex, 0);
      expect(assigned.action, DriverDeliveryAction.startPickupJourney);
      expect(pickup.stepIndex, 1);
      expect(pickup.action, DriverDeliveryAction.confirmPickup);
      expect(awaitingDeliveryStart.stepIndex, 2);
      expect(awaitingDeliveryStart.action, DriverDeliveryAction.startDelivery);
      expect(awaitingDeliveryStart.primaryLabel, 'Bắt đầu giao hàng');
      expect(delivery.stepIndex, 2);
      expect(delivery.action, DriverDeliveryAction.confirmDelivery);
      expect(delivered.stepIndex, 3);
      expect(delivered.action, DriverDeliveryAction.none);
    });

    test('only pickup and delivery confirmations require arrival', () {
      final assigned = DriverDeliveryWorkflow.fromStatus('assigned');
      final pickup = DriverDeliveryWorkflow.fromStatus('picking_up');
      final delivery = DriverDeliveryWorkflow.fromStatus('delivering');

      expect(assigned.canPerform(arrivedAtTarget: false), isTrue);
      expect(pickup.canPerform(arrivedAtTarget: false), isFalse);
      expect(pickup.canPerform(arrivedAtTarget: true), isTrue);
      expect(delivery.canPerform(arrivedAtTarget: false), isFalse);
      expect(delivery.canPerform(arrivedAtTarget: true), isTrue);
    });

    test('requires proof photos only for pickup and delivery handoffs', () {
      expect(
        DriverDeliveryAction.startPickupJourney.requiresProofPhoto,
        isFalse,
      );
      expect(DriverDeliveryAction.confirmPickup.requiresProofPhoto, isTrue);
      expect(DriverDeliveryAction.startDelivery.requiresProofPhoto, isFalse);
      expect(DriverDeliveryAction.confirmDelivery.requiresProofPhoto, isTrue);
      expect(DriverDeliveryAction.none.requiresProofPhoto, isFalse);

      expect(
        DriverDeliveryAction.confirmPickup.advancesOrderStatusImmediately,
        isFalse,
      );
      expect(
        DriverDeliveryAction.startDelivery.advancesOrderStatusImmediately,
        isTrue,
      );
    });

    test('pauses simulated movement while pickup awaits delivery start', () {
      expect(
        DriverDeliveryWorkflow.canSimulateMovement(
          status: 'picking_up',
          pickupConfirmed: true,
          arrivedAtTarget: true,
        ),
        isFalse,
      );
      expect(
        DriverDeliveryWorkflow.canSimulateMovement(
          status: 'delivering',
          pickupConfirmed: false,
          arrivedAtTarget: false,
        ),
        isTrue,
      );
    });
  });

  testWidgets('pickup confirmation stays locked until the driver arrives', (
    tester,
  ) async {
    var actionCount = 0;
    final order = _order(status: 'picking_up');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: DriverDeliveryWorkflowPanel(
              order: order,
              arrivedAtTarget: false,
              isLoading: false,
              onPrimaryAction: () => actionCount++,
            ),
          ),
        ),
      ),
    );

    final lockedButton = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text('Xác nhận đã nhận hàng'),
            matching: find.byWidgetPredicate(
              (widget) => widget is FilledButton,
            ),
          )
          .first,
    );
    expect(lockedButton.onPressed, isNull);
    expect(find.textContaining('100 m'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: DriverDeliveryWorkflowPanel(
              order: order,
              arrivedAtTarget: true,
              isLoading: false,
              onPrimaryAction: () => actionCount++,
            ),
          ),
        ),
      ),
    );

    final enabledButton = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text('Xác nhận đã nhận hàng'),
            matching: find.byWidgetPredicate(
              (widget) => widget is FilledButton,
            ),
          )
          .first,
    );
    expect(enabledButton.onPressed, isNotNull);
    await tester.tap(find.text('Xác nhận đã nhận hàng'));
    expect(actionCount, 1);
  });

  testWidgets('confirmed pickup exposes a separate start delivery action', (
    tester,
  ) async {
    var actionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: DriverDeliveryWorkflowPanel(
              order: _order(status: 'picking_up'),
              pickupConfirmed: true,
              arrivedAtTarget: true,
              isLoading: false,
              onPrimaryAction: () => actionCount++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bắt đầu giao hàng'), findsOneWidget);
    expect(find.text('Xác nhận đã nhận hàng'), findsNothing);

    await tester.tap(find.text('Bắt đầu giao hàng'));
    expect(actionCount, 1);
  });
}

OrderModel _order({required String status}) {
  final now = DateTime(2026, 7, 29, 10);
  return OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    driverId: 'driver-1',
    status: status,
    pickupAddress: '12 Nguyễn Huệ, Quận 1',
    pickupLat: 10.773,
    pickupLng: 106.703,
    deliveryAddress: '25 Lê Lợi, Quận 1',
    deliveryLat: 10.776,
    deliveryLng: 106.701,
    recipientName: 'Nguyễn Văn A',
    recipientPhone: '0900000000',
    createdAt: now,
    trackingCode: 'GH-TEST',
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
