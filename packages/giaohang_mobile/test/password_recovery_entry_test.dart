import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/auth/password_recovery/password_recovery_screen.dart';
import 'package:giaohang_mobile/features/auth/password_recovery/password_recovery_strings.dart';
import 'package:giaohang_mobile/features/auth/screens/login/login_screen.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/driver_auth_screen.dart';
import 'package:giaohang_mobile/features/auth/screens/widgets/auth_strings.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/utraffic_capture_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await prepareUtrafficCaptureFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://entry.example.test',
      anonKey: 'test-anon-key',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  for (final driver in [false, true]) {
    testWidgets(
      '${driver ? 'driver' : 'customer'} opens recovery with email and can return to login',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: driver ? const DriverAuthScreen() : const LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'prefilled@example.test',
        );
        await tester.ensureVisible(find.text(AuthStrings.forgotPassword));
        await tester.tap(find.text(AuthStrings.forgotPassword));
        await tester.pumpAndSettle();
        expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
        expect(find.text('prefilled@example.test'), findsOneWidget);
        expect(Supabase.instance.client.auth.currentSession, isNull);
        await tester.tap(find.byTooltip(PasswordRecoveryStrings.back));
        await tester.pumpAndSettle();
        expect(find.byType(PasswordRecoveryScreen), findsNothing);
        expect(find.text('prefilled@example.test'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
