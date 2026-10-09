import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/features/driver/screens/navigation/utils/driver_navigation_resume_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverNavigationResumePolicy', () {
    test('keeps a restored demo journey from being reset by device GPS', () {
      expect(
        DriverNavigationResumePolicy.shouldKeepRestoredPosition(
          hasRestoredPosition: true,
          driverEmail: 'taixe@gmail.com',
          locationMode: DriverLocationMode.demoHcm,
        ),
        isTrue,
      );
    });

    test('lets production drivers refresh from their real device GPS', () {
      expect(
        DriverNavigationResumePolicy.shouldKeepRestoredPosition(
          hasRestoredPosition: true,
          driverEmail: 'driver@example.com',
          locationMode: DriverLocationMode.deviceGps,
        ),
        isFalse,
      );
    });

    test('a demo account still receives live GPS in device mode', () {
      expect(
        DriverNavigationResumePolicy.shouldKeepRestoredPosition(
          hasRestoredPosition: true,
          driverEmail: 'taixe@gmail.com',
          locationMode: DriverLocationMode.deviceGps,
        ),
        isFalse,
      );
    });
  });
}
