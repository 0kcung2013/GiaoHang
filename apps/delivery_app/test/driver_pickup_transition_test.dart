import 'package:delivery_app/features/driver/screens/navigation/models/driver_delivery_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pickup confirmation waits for a separate delivery-start swipe', () {
    final workflow = DriverDeliveryWorkflow.fromStatus('picking_up');

    expect(workflow.action, DriverDeliveryAction.confirmPickup);
    expect(workflow.action.advancesOrderStatusImmediately, isFalse);

    final awaitingStart = DriverDeliveryWorkflow.fromStatus(
      'picking_up',
      pickupConfirmed: true,
    );
    expect(awaitingStart.action, DriverDeliveryAction.startDelivery);
    expect(awaitingStart.action.advancesOrderStatusImmediately, isTrue);
  });
}
