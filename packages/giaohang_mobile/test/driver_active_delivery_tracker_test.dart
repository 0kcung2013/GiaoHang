import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'driver shell owns active-delivery GPS independently of the map route',
    () {
      final source = File(
        'lib/features/driver/screens/driver_shell_screen.dart',
      ).readAsStringSync();

      expect(source, contains('DriverActiveDeliveryLocationTracker'));
    },
  );
}
