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
                contactTitle: 'Liên hệ người gửi',
                contactName: 'Nguyễn Văn An',
                phone: '0900000000',
                address: '12 Nguyễn Huệ, Quận 1',
                callActionLabel: 'Gọi',
                callActionDetail: 'Người gửi hoặc người nhận',
                chatActionLabel: 'Nhắn người gửi',
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
    expect(find.text('Liên hệ người gửi'), findsOneWidget);
    expect(find.text('Gọi'), findsOneWidget);
    expect(find.text('Người gửi hoặc người nhận'), findsOneWidget);
    expect(find.text('Nhắn người gửi'), findsOneWidget);
  });

  testWidgets('recipient contact only exposes the call action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showArrivalContactSheet(
                context: context,
                contactTitle: 'Liên hệ người nhận',
                contactName: 'Trần Thị B',
                phone: '0911111111',
                address: '25 Lê Lợi, Quận 1',
                callActionLabel: 'Gọi người nhận',
              ),
              child: const Text('Mở liên hệ người nhận'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở liên hệ người nhận'));
    await tester.pumpAndSettle();

    expect(find.text('Liên hệ người nhận'), findsOneWidget);
    expect(find.text('Gọi người nhận'), findsOneWidget);
    expect(find.textContaining('Nhắn'), findsNothing);
  });

  testWidgets('call action offers both sender and recipient targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    OrderCallContact? selectedContact;
    const sender = OrderCallContact(
      roleLabel: 'Người gửi',
      name: 'Nguyễn Văn An',
      phone: '0900000000',
      address: '12 Nguyễn Huệ, Quận 1',
    );
    const recipient = OrderCallContact(
      roleLabel: 'Người nhận',
      name: 'Trần Thị B',
      phone: '0911111111',
      address: '25 Lê Lợi, Quận 1',
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selectedContact = await showCallContactPickerSheet(
                  context: context,
                  sender: sender,
                  recipient: recipient,
                );
              },
              child: const Text('Gọi'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Gọi'));
    await tester.pumpAndSettle();

    expect(find.text('Bạn muốn gọi cho ai?'), findsOneWidget);
    expect(find.text('Người gửi'), findsOneWidget);
    expect(find.text('Người nhận'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Trần Thị B'), findsOneWidget);

    await tester.tap(find.byKey(const Key('call-order-recipient')));
    await tester.pumpAndSettle();

    expect(selectedContact, same(recipient));
    expect(tester.takeException(), isNull);
  });
}
