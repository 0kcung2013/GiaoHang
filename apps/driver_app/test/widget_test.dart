import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/mobile_app_role.dart';

void main() {
  test('driver app has its own session and callback', () {
    expect(MobileAppRole.driver.sessionKey, 'giaohang-driver-session');
    expect(
      MobileAppRole.driver.callbackUri,
      'com.datn.giaohang.driver://login-callback',
    );
  });
}
