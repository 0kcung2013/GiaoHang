import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/onboarding/screens/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding screen renders core content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );

    expect(find.text('Đặt hàng dễ dàng'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsNWidgets(2));
    expect(find.text('Tiếp theo'), findsOneWidget);
  });
}