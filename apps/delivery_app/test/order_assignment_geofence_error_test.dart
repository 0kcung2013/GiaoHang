import 'package:delivery_app/core/services/order_assignment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explains pickup and delivery geofence failures', () {
    expect(
      OrderAssignmentService.advanceStatusErrorMessage(
        'PostgrestException: PICKUP_OUTSIDE_GEOFENCE',
      ),
      contains('100 m'),
    );
    expect(
      OrderAssignmentService.advanceStatusErrorMessage(
        'PostgrestException: DELIVERY_OUTSIDE_GEOFENCE',
      ),
      contains('100 m'),
    );
  });
}
