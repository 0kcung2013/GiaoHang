import 'package:delivery_app/features/driver/screens/home/widgets/driver_online_pin_verification_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('setup verifies automatically after six matching digits', (
    tester,
  ) async {
    String? result;
    final verifiedPins = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDriverOnlinePinVerificationSheet(
                  context,
                  isSetup: true,
                  onVerify: (pin) async => verifiedPins.add(pin),
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin-confirmation')),
      '654321',
    );
    await tester.pump();

    expect(find.text('Hai mã PIN chưa khớp. Hãy nhập lại.'), findsOneWidget);
    expect(verifiedPins, isEmpty);
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin-confirmation')),
      '123456',
    );
    await tester.pumpAndSettle();

    expect(verifiedPins, ['123456']);
    expect(result, '123456');
  });

  testWidgets('existing PIN shows an immediate error and allows retry', (
    tester,
  ) async {
    String? result;
    final verifiedPins = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDriverOnlinePinVerificationSheet(
                  context,
                  isSetup: false,
                  onVerify: (pin) async {
                    verifiedPins.add(pin);
                    if (pin == '123456') {
                      throw Exception('Mã PIN không đúng. Bạn còn 4 lần thử.');
                    }
                  },
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('driver-online-pin-digit')),
      findsNWidgets(6),
    );

    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin')),
      '123456',
    );
    await tester.pumpAndSettle();

    expect(find.text('Mã PIN không đúng. Bạn còn 4 lần thử.'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin')),
      '654321',
    );
    await tester.pumpAndSettle();

    expect(verifiedPins, ['123456', '654321']);
    expect(result, '654321');
  });
}
