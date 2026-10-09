import 'package:delivery_app/features/auth/screens/driver_auth/wizard/driver_register_prefill.dart';
import 'package:delivery_app/features/auth/screens/register/register_screen.dart';
import 'package:delivery_app/features/auth/screens/widgets/auth_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  testWidgets('role descriptions remain visible at the reference phone width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text(AuthStrings.customerHint), findsOneWidget);
    expect(find.text(AuthStrings.driverHint), findsOneWidget);
    await tester.tap(find.text(AuthStrings.driver));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    expect(find.text(AuthStrings.driverNext), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short phone keeps focused input when keyboard opens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_app(textScale: 1.6));
    await tester.pumpAndSettle();
    final field = find.byType(TextFormField).at(1);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.enterText(field, 'customer@example.com');
    final focus = tester
        .widget<EditableText>(find.byType(EditableText).at(1))
        .focusNode;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(1))
          .controller
          .text,
      'customer@example.com',
    );
    await tester.ensureVisible(find.byType(FilledButton));
    expect(tester.takeException(), isNull);
  });

  testWidgets('validation and password visibility remain usable', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AuthStrings.missingName), findsOneWidget);
    expect(find.text(AuthStrings.missingEmail), findsOneWidget);
    expect(find.text(AuthStrings.missingPhone), findsOneWidget);
    expect(find.text(AuthStrings.missingPassword), findsOneWidget);
    await tester.ensureVisible(find.byTooltip(AuthStrings.showPassword));
    await tester.tap(find.byTooltip(AuthStrings.showPassword));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching role preserves data and forwards driver prefill', (
    tester,
  ) async {
    DriverRegisterPrefill? captured;
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        GoRoute(
          path: '/driver-auth',
          builder: (_, state) {
            captured = state.extra! as DriverRegisterPrefill;
            return const Scaffold(body: Text('driver wizard'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final values = [
      'Nguyễn Minh An',
      'an@example.com',
      '0901234567',
      'secret123',
    ];
    for (var i = 0; i < values.length; i++) {
      final field = find.byType(TextFormField).at(i);
      await tester.ensureVisible(field);
      await tester.enterText(field, values[i]);
    }
    await tester.ensureVisible(find.text(AuthStrings.driver));
    await tester.tap(find.text(AuthStrings.driver));
    await tester.pumpAndSettle();
    expect(find.text(AuthStrings.driverNote), findsOneWidget);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(captured?.fullName, values[0]);
    expect(captured?.email, values[1]);
    expect(captured?.phone, values[2]);
    expect(captured?.password, values[3]);
    expect(find.text('driver wizard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({double textScale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: const RegisterScreen(),
);
