import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android foreground location service declares the required capabilities',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final service = File(
        'lib/core/location/driver_foreground_location_service.dart',
      ).readAsStringSync();

      expect(manifest, contains('ACCESS_BACKGROUND_LOCATION'));
      expect(manifest, contains('FOREGROUND_SERVICE_LOCATION'));
      expect(manifest, contains('foregroundServiceType="location"'));
      expect(manifest, contains('stopWithTask="false"'));
      expect(service, contains('ForegroundServiceTypes.location'));
      expect(service, contains('startDriverForegroundLocationTask'));
    },
  );
}
