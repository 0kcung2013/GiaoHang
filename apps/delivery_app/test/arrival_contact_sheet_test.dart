import 'package:delivery_app/features/order_contact/widgets/arrival_contact_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('arrival contact options render after tapping contact', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showArrivalContactSheet(
                context: context,
                contactLabel: 'người tạo đơn',
                contactName: 'Nguyễn Văn An',
                phone: '0900000000',
                address: '12 Nguyễn Huệ, Quận 1',
              ),
              child: const Text('Liên hệ'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Liên hệ'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Gọi điện'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsOneWidget);
  });
}
