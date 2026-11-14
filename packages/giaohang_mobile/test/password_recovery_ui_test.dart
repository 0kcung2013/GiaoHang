import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/auth/password_recovery/data/password_recovery_service.dart';
import 'package:giaohang_mobile/features/auth/password_recovery/password_recovery_screen.dart';
import 'package:giaohang_mobile/features/auth/password_recovery/password_recovery_strings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/utraffic_capture_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareUtrafficCaptureFonts);

  testWidgets(
    'validates each step, accepts pasted OTP and returns after explicit success',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final gateway = _Gateway();
      String? recoveredEmail;
      await tester.pumpWidget(
        _app(gateway, onRecovered: (email) => recoveredEmail = email),
      );
      await _tap(tester, 'Mở khôi phục');
      await tester.pumpAndSettle();
      await _capture(tester, 'email');
      await _tap(tester, PasswordRecoveryStrings.send);
      expect(gateway.emails, isEmpty);
      expect(find.text(PasswordRecoveryStrings.missingEmail), findsOneWidget);
      await tester.enterText(_input('recovery-email'), 'customer@example.test');
      await _tap(tester, PasswordRecoveryStrings.send);
      expect(gateway.emails, ['customer@example.test']);
      expect(find.text(PasswordRecoveryStrings.deliveryNotice), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(
                TextButton,
                PasswordRecoveryStrings.resendIn(60),
              ),
            )
            .onPressed,
        isNull,
      );
      await _capture(tester, 'code');
      await _tap(tester, PasswordRecoveryStrings.verify);
      expect(gateway.codes, isEmpty);
      await tester.enterText(_input('recovery-code'), '001234');
      await _tap(tester, PasswordRecoveryStrings.verify);
      expect(gateway.codes, ['001234']);
      await _capture(tester, 'password');
      await tester.enterText(_input('recovery-password'), 'NewPassword9!');
      await tester.enterText(_input('recovery-confirm'), 'different');
      await _tap(tester, PasswordRecoveryStrings.save);
      expect(find.text(PasswordRecoveryStrings.mismatch), findsOneWidget);
      expect(gateway.passwords, isEmpty);
      await tester.enterText(_input('recovery-confirm'), 'NewPassword9!');
      await _tap(tester, PasswordRecoveryStrings.save);
      expect(gateway.passwords, ['NewPassword9!']);
      expect(find.text(PasswordRecoveryStrings.successTitle), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await _capture(tester, 'success');
      expect(tester.takeException(), isNull);
      expect(recoveredEmail, isNull);
      await _tap(tester, PasswordRecoveryStrings.login);
      expect(recoveredEmail, 'customer@example.test');
      expect(find.byType(PasswordRecoveryScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(gateway.disposed, isTrue);
    },
  );

  testWidgets('prevents duplicate sends and closing during a request is safe', (
    tester,
  ) async {
    final pending = Completer<void>();
    final gateway = _Gateway()..pendingSend = pending;
    await tester.pumpWidget(_app(gateway, email: 'prefilled@example.test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PasswordRecoveryStrings.send));
    await tester.pump();
    expect(find.text(PasswordRecoveryStrings.sending), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const ValueKey('recovery-submit')),
          )
          .onPressed,
      isNull,
    );
    expect(gateway.emails, ['prefilled@example.test']);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pumpAndSettle();
    expect(gateway.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP and expired session errors keep recovery available', (
    tester,
  ) async {
    final gateway = _Gateway();
    await tester.pumpWidget(_app(gateway, email: 'customer@example.test'));
    await tester.pumpAndSettle();
    await _tap(tester, PasswordRecoveryStrings.send);
    gateway.verifyError = const AuthException('Expired', code: 'otp_expired');
    await tester.enterText(_input('recovery-code'), '123456');
    await _tap(tester, PasswordRecoveryStrings.verify);
    expect(find.text(PasswordRecoveryStrings.codeExpired), findsOneWidget);
    gateway.verifyError = null;
    await _tap(tester, PasswordRecoveryStrings.verify);
    await tester.enterText(_input('recovery-password'), 'NewPassword9!');
    await tester.enterText(_input('recovery-confirm'), 'NewPassword9!');
    gateway.saveError = const AuthException(
      'Expired session',
      code: 'session_expired',
    );
    await _tap(tester, PasswordRecoveryStrings.save);
    expect(find.text(PasswordRecoveryStrings.sessionExpired), findsOneWidget);
    expect(_input('recovery-code'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1200, 800),
  ]) {
    testWidgets('all form steps fit $size with large text and keyboard', (
      tester,
    ) async {
      _viewport(tester, size);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      final gateway = _Gateway();
      await tester.pumpWidget(
        _app(gateway, email: 'customer@example.test', largeText: true),
      );
      await tester.pumpAndSettle();
      await _tap(tester, PasswordRecoveryStrings.send);
      await tester.ensureVisible(_input('recovery-code'));
      await tester.enterText(_input('recovery-code'), '123456');
      await _tap(tester, PasswordRecoveryStrings.verify);
      await tester.ensureVisible(_input('recovery-password'));
      await tester.enterText(_input('recovery-password'), 'NewPassword9!');
      await tester.ensureVisible(_input('recovery-confirm'));
      await tester.enterText(_input('recovery-confirm'), 'NewPassword9!');
      await tester.ensureVisible(find.byTooltip('Hiện mật khẩu').last);
      await tester.tap(find.byTooltip('Hiện mật khẩu').last);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: _input('recovery-confirm'),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isFalse,
      );
      await _tap(tester, PasswordRecoveryStrings.save);
      expect(find.text(PasswordRecoveryStrings.successTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Finder _input(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextFormField),
);

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Widget _app(
  _Gateway gateway, {
  String email = '',
  bool largeText = false,
  ValueChanged<String?>? onRecovered,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(largeText ? 1.6 : 1),
      disableAnimations: true,
    ),
    child: child!,
  ),
  home: onRecovered == null
      ? _screen(gateway, email)
      : Builder(
          builder: (context) => TextButton(
            onPressed: () async => onRecovered(
              await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => _screen(gateway, email)),
              ),
            ),
            child: const Text('Mở khôi phục'),
          ),
        ),
);

Widget _screen(_Gateway gateway, String email) => RepaintBoundary(
  key: const ValueKey('recovery-capture'),
  child: PasswordRecoveryScreen(initialEmail: email, gateway: gateway),
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_PASSWORD_RECOVERY')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('recovery-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../../artifacts/password_recovery/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _Gateway implements PasswordRecoveryGateway {
  final emails = <String>[];
  final codes = <String>[];
  final passwords = <String>[];
  Completer<void>? pendingSend;
  Object? verifyError;
  Object? saveError;
  bool disposed = false;
  @override
  Future<void> sendCode(String email) async {
    emails.add(email);
    await pendingSend?.future;
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    codes.add(code);
    if (verifyError != null) throw verifyError!;
  }

  @override
  Future<void> updatePassword(String password) async {
    passwords.add(password);
    if (saveError != null) throw saveError!;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
