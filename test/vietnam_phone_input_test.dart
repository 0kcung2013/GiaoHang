import 'package:customer_app/features/customer/screens/create_order/utils/vietnam_phone_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeVietnamPhone', () {
    test('adds the leading zero and keeps at most 11 digits', () {
      expect(normalizeVietnamPhone('912 345 678'), '0912345678');
      expect(normalizeVietnamPhone('01234567890123'), '01234567890');
    });

    test('converts the Vietnam country code to a leading zero', () {
      expect(normalizeVietnamPhone('+84 912 345 678'), '0912345678');
    });
  });

  group('validateVietnamPhone', () {
    test('accepts 10 or 11 digit local phone numbers', () {
      expect(validateVietnamPhone('0912345678'), isNull);
      expect(validateVietnamPhone('01234567890'), isNull);
    });

    test('rejects invalid local phone numbers', () {
      expect(validateVietnamPhone('912345678'), isNotNull);
      expect(validateVietnamPhone('091234567'), isNotNull);
      expect(validateVietnamPhone('091234567890'), isNotNull);
    });
  });
}
