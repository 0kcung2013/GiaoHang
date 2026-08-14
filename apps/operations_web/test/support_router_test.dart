import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/router.dart';

void main() {
  test('support defaults to the risk workspace', () {
    expect(createOperationsRouter, isNotNull);
    final source = File('lib/router.dart').readAsStringSync();

    expect(
      source,
      contains("role == 'admin' ? '/admin-home' : '/support-risk'"),
    );
    expect(source, contains("return '/support-risk';"));
  });
}
