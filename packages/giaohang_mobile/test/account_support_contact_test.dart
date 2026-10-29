import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/auth/screens/widgets/account_support_contact.dart';
import 'package:giaohang_mobile/features/auth/screens/widgets/auth_strings.dart';
import 'package:giaohang_mobile/features/auth/screens/login/widgets/login_experiment_form.dart';

import 'helpers/customer_account_fixtures.dart';

void main() {
  setUpAll(loadCustomerAccountTestFonts);

  testWidgets(
    'email launch uses the supplied CSKH address and supports copy on failure',
    (tester) async {
      Uri? launched;
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountSupportContact(
              launchEmail: (uri) async {
                launched = uri;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text(AuthStrings.contactSupport));
      await tester.pumpAndSettle();
      expect(launched!.scheme, 'mailto');
      expect(launched!.path, 'cskh@gmail.com');
      expect(
        launched!.queryParameters['subject'],
        AuthStrings.disabledAccountSubject,
      );
      expect(
        launched!.queryParameters['body'],
        AuthStrings.disabledAccountBody,
      );
      expect(launched!.query, isNot(contains('+')));
      expect(find.text(AuthStrings.supportEmailUnavailable), findsOneWidget);
      await tester.tap(find.byTooltip(AuthStrings.copySupportEmail));
      await tester.pumpAndSettle();
      expect(copied, 'cskh@gmail.com');
      expect(find.text(AuthStrings.supportEmailCopied), findsOneWidget);
    },
  );

  testWidgets(
    'an email handler exception keeps the contact address available',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountSupportContact(
              launchEmail: (_) async => throw Exception('No handler'),
            ),
          ),
        ),
      );
      await tester.tap(find.text(AuthStrings.contactSupport));
      await tester.pumpAndSettle();
      expect(find.text(AuthStrings.supportEmailUnavailable), findsOneWidget);
      expect(find.text(AuthStrings.supportEmail), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('email launch cannot be submitted twice while pending', (
    tester,
  ) async {
    final pending = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSupportContact(
            launchEmail: (_) {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text(AuthStrings.contactSupport));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byWidgetPredicate((widget) => widget is OutlinedButton),
          )
          .onPressed,
      isNull,
    );
    expect(calls, 1);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text(AuthStrings.supportEmailUnavailable), findsNothing);
  });

  testWidgets(
    'disabled login shows contact while ordinary login errors do not',
    (tester) async {
      final email = TextEditingController();
      final password = TextEditingController();
      addTearDown(email.dispose);
      addTearDown(password.dispose);
      Widget form(String error) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LoginExperimentFormSurface(
              isWide: false,
              compactVertical: true,
              hideSecondaryActions: true,
              formKey: GlobalKey<FormState>(),
              emailController: email,
              passwordController: password,
              isBusy: false,
              obscurePassword: true,
              errorMessage: error,
              emailValidator: (_) => null,
              passwordValidator: (_) => null,
              onEmailSignIn: () {},
              onGoogleSignIn: () {},
              onTogglePassword: () {},
              onRegister: () {},
              onPasswordSubmitted: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(form(AuthStrings.accountDisabled));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSupportContact), findsOneWidget);
      await tester.pumpWidget(form(AuthStrings.loginFailed));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSupportContact), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
