import 'package:delivery_app/features/auth/screens/login/widgets/login_experiment_view.dart';
import 'package:delivery_app/features/auth/screens/widgets/auth_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  testWidgets('login experiment fits a small phone with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _LoginHarness(textScaler: const TextScaler.linear(1.6)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing);
    final heroRect = tester.getRect(find.byKey(const Key('login-hero-panel')));
    final imageRect = tester.getRect(
      find.byKey(const Key('login-courier-hero')),
    );
    expect(imageRect.top, greaterThanOrEqualTo(heroRect.top));
    expect(find.text(AuthStrings.appName), findsOneWidget);
    expect(
      find.bySemanticsLabel(AuthStrings.loginIllustrationLabel),
      findsOneWidget,
    );
    expect(find.text(AuthStrings.loginTitle), findsOneWidget);
    expect(find.text(AuthStrings.email), findsOneWidget);
    expect(find.text(AuthStrings.password), findsOneWidget);
  });

  testWidgets('login experiment adapts to a large screen', (tester) async {
    var googleSignInCount = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _LoginHarness(onGoogleSignIn: () => googleSignInCount++),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(AuthStrings.appName), findsOneWidget);
    expect(find.text(AuthStrings.loginWithGoogle), findsOneWidget);
    expect(find.byKey(const Key('login-google-icon')), findsOneWidget);
    final googleMark = tester.widget<SvgPicture>(
      find.descendant(
        of: find.byKey(const Key('login-google-icon')),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(googleMark.bytesLoader, isA<SvgStringLoader>());
    expect(find.text(AuthStrings.registerNow), findsOneWidget);
    await tester.tap(find.text(AuthStrings.loginWithGoogle));
    expect(googleSignInCount, 1);
  });

  testWidgets('courier hero asset is bundled and intersects the hero', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const _LoginHarness());
    await tester.pumpAndSettle();

    final data = await rootBundle.load('assets/images/login_courier_hero.png');
    expect(data.lengthInBytes, greaterThan(1000000));

    final heroRect = tester.getRect(find.byKey(const Key('login-hero-panel')));
    final imageRect = tester.getRect(
      find.byKey(const Key('login-courier-hero')),
    );
    final visibleRect = heroRect.intersect(imageRect);

    expect(visibleRect.width, greaterThan(200));
    expect(visibleRect.height, greaterThan(250));
  });

  testWidgets('email keeps focus when keyboard insets appear', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const _LoginHarness());
    await tester.pumpAndSettle();

    final emailField = find.byType(TextFormField).first;
    await tester.tap(emailField);
    await tester.pump();

    final focusBeforeKeyboard = tester
        .widget<EditableText>(find.byType(EditableText).first)
        .focusNode;
    expect(focusBeforeKeyboard.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final focusAfterKeyboard = tester
        .widget<EditableText>(find.byType(EditableText).first)
        .focusNode;
    expect(focusAfterKeyboard, same(focusBeforeKeyboard));
    expect(focusAfterKeyboard.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login experiment exposes validation and password visibility', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    var passwordVisible = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => LoginExperimentView(
            formKey: formKey,
            emailController: TextEditingController(),
            passwordController: TextEditingController(),
            isBusy: false,
            obscurePassword: !passwordVisible,
            emailValidator: (value) => value == null || value.isEmpty
                ? AuthStrings.missingEmail
                : null,
            passwordValidator: (value) => value == null || value.isEmpty
                ? AuthStrings.missingPassword
                : null,
            onEmailSignIn: () => formKey.currentState!.validate(),
            onGoogleSignIn: () {},
            onTogglePassword: () =>
                setState(() => passwordVisible = !passwordVisible),
            onRegister: () {},
            onPasswordSubmitted: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(AuthStrings.login));
    await tester.tap(find.text(AuthStrings.login));
    await tester.pumpAndSettle();

    expect(find.text(AuthStrings.missingEmail), findsOneWidget);
    expect(find.text(AuthStrings.missingPassword), findsOneWidget);

    await tester.tap(find.byTooltip(AuthStrings.showPassword));
    await tester.pumpAndSettle();
    expect(find.byTooltip(AuthStrings.hidePassword), findsOneWidget);
  });
}

class _LoginHarness extends StatelessWidget {
  const _LoginHarness({
    this.textScaler = TextScaler.noScaling,
    this.onGoogleSignIn,
  });

  final TextScaler textScaler;
  final VoidCallback? onGoogleSignIn;

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    return MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
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
        onGoogleSignIn: onGoogleSignIn ?? () {},
        onTogglePassword: () {},
        onRegister: () {},
        onPasswordSubmitted: (_) {},
      ),
    );
  }
}
