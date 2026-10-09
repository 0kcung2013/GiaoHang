import 'package:delivery_app/core/location/driver_active_delivery_tracking_policy.dart';
import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverActiveDeliveryTrackingPolicy', () {
    test(
      'resumes live GPS after closing map with a saved navigation session',
      () {
        expect(
          DriverActiveDeliveryTrackingPolicy.shouldUseLiveGps(
            isWeb: false,
            locationMode: DriverLocationMode.deviceGps,
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
            isWeb: false,
            locationMode: DriverLocationMode.deviceGps,
            isNavigationMapOpen: true,
            hasRestoredNavigationSession: false,
          ),
          isFalse,
        );
      },
    );

    test(
      'continues demo publishing on Android after closing an active trip map',
      () {
        expect(
          DriverActiveDeliveryTrackingPolicy.shouldRunDemoPublisher(
            isWeb: false,
            locationMode: DriverLocationMode.demoHcm,
            isNavigationMapOpen: false,
            hasRestoredNavigationSession: true,
            canSimulateMovement: true,
          ),
          isTrue,
        );
      },
    );

    test('current-position simulation keeps publishing after map closes', () {
      expect(
        DriverActiveDeliveryTrackingPolicy.shouldRunDemoPublisher(
          isWeb: false,
          locationMode: DriverLocationMode.demoCurrentPosition,
          isNavigationMapOpen: false,
          hasRestoredNavigationSession: true,
          canSimulateMovement: true,
        ),
        isTrue,
      );
      expect(
        DriverActiveDeliveryTrackingPolicy.shouldUseLiveGps(
          isWeb: false,
          locationMode: DriverLocationMode.demoCurrentPosition,
          isNavigationMapOpen: false,
          hasRestoredNavigationSession: true,
        ),
        isFalse,
      );
    });

    test('uses route simulation for web and Android demo mode', () {
      expect(
        DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
          isWeb: true,
          locationMode: DriverLocationMode.deviceGps,
        ),
        isTrue,
      );
      expect(
        DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
          isWeb: false,
          locationMode: DriverLocationMode.demoHcm,
        ),
        isTrue,
      );
      expect(
        DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
          isWeb: false,
          locationMode: DriverLocationMode.deviceGps,
        ),
        isFalse,
      );
      expect(
        DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
          isWeb: false,
          locationMode: DriverLocationMode.demoCurrentPosition,
        ),
        isTrue,
      );
    });

    test('does not let Android live GPS overwrite a restored demo session', () {
      expect(
        DriverActiveDeliveryTrackingPolicy.shouldUseLiveGps(
          isWeb: false,
          locationMode: DriverLocationMode.demoHcm,
          isNavigationMapOpen: false,
          hasRestoredNavigationSession: true,
        ),
        isFalse,
      );
    });
  });
}
