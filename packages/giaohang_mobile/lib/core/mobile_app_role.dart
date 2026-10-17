/// Identity is fixed by the executable, never selected by the signed-in user.
enum MobileAppRole {
  customer,
  driver;

  String get sessionKey => 'giaohang-$name-session';
  String get callbackUri => 'com.datn.giaohang.$name://login-callback';
  String get appName => switch (this) {
    customer => 'Giao Hàng — Khách hàng',
    driver => 'Giao Hàng — Tài xế',
  };
  String get homeRoute => '/$name-home';
  bool accepts(String? accountRole) => accountRole == name;
}
