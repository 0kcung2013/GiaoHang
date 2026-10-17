import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/mobile_app_role.dart';

void main() {
  test('customer app has its own session and callback', () {
    expect(MobileAppRole.customer.sessionKey, 'giaohang-customer-session');
    expect(
      MobileAppRole.customer.callbackUri,
      'com.datn.giaohang.customer://login-callback',
    );
  });
}
