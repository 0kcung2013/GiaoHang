import 'package:giaohang_mobile/features/driver/screens/navigation/models/driver_delivery_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pickup confirmation advances to delivery; interrupted transitions can retry',
    () {
      final workflow = DriverDeliveryWorkflow.fromStatus('picking_up');

      expect(workflow.action, DriverDeliveryAction.confirmPickup);
      expect(workflow.action.advancesOrderStatusImmediately, isTrue);

      final awaitingStart = DriverDeliveryWorkflow.fromStatus(
        'picking_up',
        pickupConfirmed: true,
      );
      expect(awaitingStart.action, DriverDeliveryAction.startDelivery);
      expect(awaitingStart.action.advancesOrderStatusImmediately, isTrue);
    },
  );
}
