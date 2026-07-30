import 'package:customer_app/core/location/driver_location_producer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverLocationProducerPolicy', () {
    test('background GPS pauses while navigation owns location publishing', () {
      expect(
        DriverLocationProducerPolicy.canPublishBackgroundGps(null),
        isTrue,
      );
      expect(
        DriverLocationProducerPolicy.canPublishBackgroundGps('order-1'),
        isFalse,
      );
    });

    test('only raw GPS coordinates receive the configured demo offset', () {
      expect(
        LocationIngestCoordinateSpace.rawGps.shouldApplyDemoOffset,
        isTrue,
      );
      expect(
        LocationIngestCoordinateSpace.mapCoordinates.shouldApplyDemoOffset,
        isFalse,
      );
    });
  });
}
