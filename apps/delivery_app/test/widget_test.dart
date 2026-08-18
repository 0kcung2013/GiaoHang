import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delivery_app/features/auth/screens/widgets/auth_role_selector.dart';
import 'package:delivery_app/features/auth/screens/widgets/auth_shell.dart';
import 'package:delivery_app/features/auth/screens/widgets/auth_strings.dart';

void main() {
  testWidgets('startup auth shell renders brand and login content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthShell(
          title: AuthStrings.loginTitle,
          subtitle: AuthStrings.loginSubtitle,
          child: Text(AuthStrings.login),
        ),
      ),
    );

    expect(find.text(AuthStrings.appName), findsOneWidget);
    expect(find.text(AuthStrings.loginTitle), findsOneWidget);
    expect(find.text(AuthStrings.login), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);
  });

  testWidgets('register role selector switches to driver', (tester) async {
    var role = 'customer';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AuthRoleSelector(
              role: role,
              onChanged: (value) => setState(() => role = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(AuthStrings.driver));
    await tester.pump();

    expect(role, 'driver');
    expect(
      tester
          .getSemantics(find.text(AuthStrings.driver))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      isTrue,
    );
  });

  testWidgets('auth layout handles mobile width and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: AuthShell(
          title: AuthStrings.registerTitle,
          subtitle: AuthStrings.registerSubtitle,
          child: AuthRoleSelector(role: 'customer', onChanged: (_) {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(AuthStrings.customer), findsOneWidget);
    expect(find.text(AuthStrings.driver), findsOneWidget);
  });
}
