import 'package:giaohang_mobile/features/auth/screens/register/register_screen.dart';
import 'package:giaohang_mobile/features/auth/screens/widgets/auth_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('customer registration has no driver role choice', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text(AuthStrings.driver), findsNothing);
    expect(find.text(AuthStrings.driverNext), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(4));
    await tester.ensureVisible(find.byType(FilledButton));
    expect(find.text(AuthStrings.register), findsOneWidget);
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
