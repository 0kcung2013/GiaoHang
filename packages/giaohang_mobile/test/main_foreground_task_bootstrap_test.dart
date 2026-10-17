import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Only native driver app initializes foreground tracking',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final webGuard = source.indexOf('if (!kIsWeb && role == MobileAppRole.driver) {');
      final communicationPort = source.indexOf(
        'FlutterForegroundTask.initCommunicationPort()',
      );

      expect(webGuard, greaterThanOrEqualTo(0));
      expect(communicationPort, greaterThan(webGuard));
    },
  );
}
