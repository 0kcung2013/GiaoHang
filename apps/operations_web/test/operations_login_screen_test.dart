import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/auth/operations_login_screen.dart';

void main() {
  testWidgets('operations login is limited to Support and Admin', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OperationsLoginScreen()));

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(
      find.text('Đăng nhập Trung tâm vận hành dành cho Admin và CSKH.'),
      findsOneWidget,
    );
    expect(find.text('Tài khoản hoặc email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OperationsLoginScreen()));

    final passwordFinder = find.byKey(const Key('operations-password-field'));
    expect(tester.widget<TextField>(passwordFinder).obscureText, isTrue);

    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();

    expect(tester.widget<TextField>(passwordFinder).obscureText, isFalse);
  });
}
