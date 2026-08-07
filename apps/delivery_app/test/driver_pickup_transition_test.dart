import 'package:delivery_app/features/driver/screens/navigation/models/driver_delivery_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pickup confirmation atomically advances the order to delivery', () {
    final workflow = DriverDeliveryWorkflow.fromStatus('picking_up');

    expect(workflow.action, DriverDeliveryAction.confirmPickup);
    expect(workflow.action.advancesOrderStatusImmediately, isTrue);
  });
}
