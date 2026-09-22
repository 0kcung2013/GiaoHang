import 'package:delivery_app/features/driver/screens/home/widgets/driver_online_pin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('legacy entrypoint uses automatic six digit verification', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDriverOnlinePinVerificationSheet(
                  context,
                  isSetup: true,
                  onVerify: (_) async {},
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
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin-confirmation')),
      '123456',
    );
    await tester.pumpAndSettle();

    expect(result, '123456');
  });
}
