import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Web does not initialize the Android foreground-task communication port',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final webGuard = source.indexOf('if (!kIsWeb) {');
      final communicationPort = source.indexOf(
        'FlutterForegroundTask.initCommunicationPort()',
      );

      expect(webGuard, greaterThanOrEqualTo(0));
      expect(communicationPort, greaterThan(webGuard));
    },
  );
}
