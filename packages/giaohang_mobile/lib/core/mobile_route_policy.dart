import 'mobile_app_role.dart';

/// UI routing only. Backend policies remain the authorization boundary.
String? mobileRouteRedirect({
  required MobileAppRole app,
  required String location,
  required bool signedIn,
  String? accountRole,
  String? driverApproval,
  bool customerClassified = true,
}) {
  final public = location == '/login' || location == '/register';
  if (!signedIn) return public ? null : '/login';
  if (!app.accepts(accountRole)) {
    return location == '/unsupported-role' ? null : '/unsupported-role';
  }
  // Signing up creates the session before the KYC upload completes.
  if (location == '/register') return null;
  if (app == MobileAppRole.customer &&
      !customerClassified &&
      location != '/help' &&
      location != '/customer-classification') {
    return '/customer-classification';
  }
  if (app == MobileAppRole.customer &&
      customerClassified &&
      location == '/customer-classification') {
    return app.homeRoute;
  }
  if (app == MobileAppRole.driver && driverApproval != 'approved') {
    return location == '/driver-pending' ? null : '/driver-pending';
  }
  if (location == '/' ||
      public ||
      location == '/unsupported-role' ||
      location == '/driver-pending' ||
      location == '/operations-required' ||
      (app == MobileAppRole.customer && location.startsWith('/driver-')) ||
      (app == MobileAppRole.driver && location.startsWith('/customer'))) {
    return app.homeRoute;
  }
  return null;
}
