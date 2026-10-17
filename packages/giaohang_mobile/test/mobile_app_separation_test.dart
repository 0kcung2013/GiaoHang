import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/mobile_app_role.dart';
import 'package:giaohang_mobile/core/mobile_route_policy.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/driver_auth_screen.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/widgets/driver_login_form.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/widgets/driver_register_form.dart';
import 'package:giaohang_mobile/features/auth/screens/widgets/auth_strings.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final app in MobileAppRole.values) {
    for (final account in ['customer', 'driver', 'support', 'admin', null]) {
      test('${app.name} rejects incompatible account $account', () {
        expect(
          mobileRouteRedirect(
            app: app,
            location: app.homeRoute,
            signedIn: true,
            accountRole: account,
            driverApproval: 'approved',
          ),
          account == app.name ? null : '/unsupported-role',
        );
      });
    }
    test('${app.name} requires login even for protected deep link', () {
      expect(
        mobileRouteRedirect(app: app, location: app.homeRoute, signedIn: false),
        '/login',
      );
    });
    test('${app.name} accepts public registration without session', () {
      expect(
        mobileRouteRedirect(app: app, location: '/register', signedIn: false),
        isNull,
      );
    });
  }
  test('driver must be approved, including restored sessions', () {
    for (final approval in [null, 'pending', 'rejected']) {
      expect(
        mobileRouteRedirect(
          app: MobileAppRole.driver,
          location: '/driver-home',
          signedIn: true,
          accountRole: 'driver',
          driverApproval: approval,
        ),
        '/driver-pending',
      );
    }
  });
  test('KYC registration survives the intermediate signed-in event', () {
    expect(
      mobileRouteRedirect(
        app: MobileAppRole.driver,
        location: '/register',
        signedIn: true,
        accountRole: 'driver',
      ),
      isNull,
    );
    expect(
      mobileRouteRedirect(
        app: MobileAppRole.driver,
        location: '/register',
        signedIn: true,
        accountRole: 'customer',
      ),
      '/unsupported-role',
    );
  });
  test('sessions and callbacks cannot collide between apps', () {
    expect(
      MobileAppRole.customer.sessionKey,
      isNot(MobileAppRole.driver.sessionKey),
    );
    expect(
      MobileAppRole.customer.callbackUri,
      isNot(MobileAppRole.driver.callbackUri),
    );
  });

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test',
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final size in [const Size(360, 640), const Size(1280, 800)]) {
    testWidgets('driver login opens independent KYC at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const DriverAuthScreen()),
          GoRoute(
            path: '/register',
            builder: (_, _) => const DriverAuthScreen(register: true),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(DriverLoginForm), findsOneWidget);
      expect(find.byType(DriverRegisterForm), findsNothing);
      await tester.tap(find.text(AuthStrings.driverRegistrationTitle));
      await tester.pumpAndSettle();
      expect(find.byType(DriverRegisterForm), findsOneWidget);
      expect(find.byType(DriverLoginForm), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(AuthStrings.backToLogin));
      await tester.pumpAndSettle();
      expect(find.byType(DriverLoginForm), findsOneWidget);
    });
  }
}
