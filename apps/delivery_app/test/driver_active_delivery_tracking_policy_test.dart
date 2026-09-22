import 'package:delivery_app/core/location/driver_active_delivery_tracking_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverActiveDeliveryTrackingPolicy', () {
    test(
      'resumes live GPS after closing map with a saved navigation session',
      () {
        expect(
          DriverActiveDeliveryTrackingPolicy.shouldUseLiveGps(
            isNavigationMapOpen: false,
            hasRestoredNavigationSession: true,
          ),
          isTrue,
        );
      },
    );

    test(
      'leaves location publishing to the navigation map while it is open',
      () {
        expect(
          DriverActiveDeliveryTrackingPolicy.shouldUseLiveGps(
            isNavigationMapOpen: true,
            hasRestoredNavigationSession: false,
          ),
          isFalse,
        );
      },
    );

    test(
      'continues demo publishing after closing map during an active trip',
      () {
        expect(
          DriverActiveDeliveryTrackingPolicy.shouldRunDemoPublisher(
            isNavigationMapOpen: false,
            hasRestoredNavigationSession: true,
            canSimulateMovement: true,
          ),
          isTrue,
        );
      },
    );
  });
}
