import 'package:delivery_app/features/auth/screens/login/widgets/login_experiment_view.dart';
import 'package:delivery_app/features/auth/screens/widgets/auth_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login experiment renders with reduced motion enabled', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: LoginExperimentView(
          formKey: formKey,
          emailController: TextEditingController(),
          passwordController: TextEditingController(),
          isBusy: false,
          obscurePassword: true,
          emailValidator: (_) => null,
          passwordValidator: (_) => null,
          onEmailSignIn: () {},
          onGoogleSignIn: () {},
          onTogglePassword: () {},
          onRegister: () {},
          onPasswordSubmitted: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(AuthStrings.appName), findsOneWidget);
    expect(
      find.bySemanticsLabel(AuthStrings.loginIllustrationLabel),
      findsOneWidget,
    );
    expect(find.text(AuthStrings.loginTitle), findsOneWidget);
    expect(
      tester
          .widget<FadeTransition>(find.byType(FadeTransition).first)
          .opacity
          .value,
      1,
    );
  });
}
