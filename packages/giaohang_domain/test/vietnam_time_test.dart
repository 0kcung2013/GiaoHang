import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  group('VietnamTime', () {
    test(
      'converts a UTC instant to UTC+7 independently of device timezone',
      () {
        final result = VietnamTime.toWallClock(
          DateTime.parse('2026-08-16T18:30:00Z'),
        );

        expect(result, DateTime(2026, 8, 17, 1, 30));
      },
    );

    test('uses Vietnam calendar dates around the UTC day boundary', () {
      final result = VietnamTime.toWallClock(
        DateTime.parse('2026-08-16T17:00:00Z'),
      );

      expect(VietnamTime.dateOnly(result), DateTime(2026, 8, 17));
    });
  });
}
